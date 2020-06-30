require 'tempfile'
require 'fastlane/action'
require 'open3'
require 'shellwords'
require 'googleauth'
require_relative './firebase_app_distribution_login'
require_relative '../helper/upload_status_response'
require_relative '../helper/firebase_app_distribution_helper'
require_relative '../helper/firebase_app_distribution_error_message'

## TODO: should always use a file underneath? I think so.
## How should we document the usage of release notes?
module Fastlane
  module Actions
    class FirebaseAppDistributionAction < Action
      DEFAULT_FIREBASE_CLI_PATH = `which firebase`
      FIREBASECMD_ACTION = "appdistribution:distribute".freeze
      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      TOKEN_PATH = "https://oauth2.googleapis.com/token"
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_SECONDS = 2

      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        params.values # to validate all inputs before looking for the ipa/apk
        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
        binary_path = params[:ipa_path] || params[:apk_path]

        if params[:app] # Set app_id if it is specified as a parameter
          app_id = params[:app]
        elsif platform == :ios
          archive_path = Actions.lane_context[SharedValues::XCODEBUILD_ARCHIVE]
          if archive_path
            app_id = get_ios_app_id_from_archive(archive_path)
          end
        end

        if app_id.nil?
          UI.crash!(ErrorMessage::MISSING_APP_ID)
        end
        release_id = upload(app_id, binary_path)
        post_notes(app_id, release_id, params[:release_notes])
      ensure
        cleanup_tempfiles
      end

      def self.connection
        @connection ||= Faraday.new(url: BASE_URL) do |conn|
          conn.response(:json, parser_options: { symbolize_names: true })
          conn.response(:raise_error) # raise_error middleware will run before the json middleware
          conn.adapter(Faraday.default_adapter)
        end
      end

      def self.v1_apps_path(app_id)
        "/v1alpha/apps/#{app_id}"
      end
      
      def self.auth_token
        @auth_token ||= begin
          client = Signet::OAuth2::Client.new(
            token_credential_uri: TOKEN_PATH,
            client_id: FirebaseAppDistributionLoginAction::CLIENT_ID,
            client_secret: FirebaseAppDistributionLoginAction::CLIENT_SECRET,
            refresh_token: ENV["FIREBASE_TOKEN"]
          )
          client.fetch_access_token!
          return client.access_token
        rescue Signet::AuthorizationError
          UI.crash!(ErrorMessage::REFRESH_TOKEN_ERROR)
        end
      end

      def self.description
        "Release your beta builds with Firebase App Distribution"
      end

      def self.authors
        ["Stefan Natchev", "Manny Jimenez Github: mannyjimenez0810, Alonso Salas Infante Github: alonsosalasinfante"]
      end

      # supports markdown.
      def self.details
        "Release your beta builds with Firebase App Distribution"
      end

      def self.available_options
        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        if platform == :ios || platform.nil?
          ipa_path_default = Dir["*.ipa"].sort_by { |x| File.mtime(x) }.last
        end

        if platform == :android
          apk_path_default = Dir["*.apk"].last || Dir[File.join("app", "build", "outputs", "apk", "app-release.apk")].last
        end

        [
          # iOS Specific
          FastlaneCore::ConfigItem.new(key: :ipa_path,
                                       env_name: "FIREBASEAPPDISTRO_IPA_PATH",
                                       description: "Path to your IPA file. Optional if you use the _gym_ or _xcodebuild_ action",
                                       default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH] || ipa_path_default,
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("firebase_app_distribution: Couldn't find ipa file at path '#{value}'") unless File.exist?(value)
                                       end),
          # Android Specific
          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       env_name: "FIREBASEAPPDISTRO_APK_PATH",
                                       description: "Path to your APK file",
                                       default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH] || apk_path_default,
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("firebase_app_distribution: Couldn't find apk file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :app,
                                       env_name: "FIREBASEAPPDISTRO_APP",
                                       description: "Your app's Firebase App ID. You can find the App ID in the Firebase console, on the General Settings page",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :firebase_cli_path,
                                       env_name: "FIREBASEAPPDISTRO_FIREBASE_CLI_PATH",
                                       description: "The absolute path of the firebase cli command",
                                       default_value: DEFAULT_FIREBASE_CLI_PATH,
                                       default_value_dynamic: true,
                                       optional: false,
                                       type: String,
                                       verify_block: proc do |value|
                                         value.chomp!
                                         if value.to_s == "" || !File.exist?(value)
                                           UI.user_error!("firebase_cli_path: missing path to firebase cli tool. Please install firebase in $PATH or specify path")
                                         end

                                         unless is_firebasecmd_supported?(value)
                                           UI.user_error!("firebase_cli_path: `#{value}` does not support the `#{FIREBASECMD_ACTION}` command. Please download (https://appdistro.page.link/firebase-cli-download) or specify the path to the correct version of firebse")
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :groups,
                                       env_name: "FIREBASEAPPDISTRO_GROUPS",
                                       description: "The groups used for distribution, separated by commas",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :groups_file,
                                       env_name: "FIREBASEAPPDISTRO_GROUPS_FILE",
                                       description: "The groups used for distribution, separated by commas",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :testers,
                                       env_name: "FIREBASEAPPDISTRO_TESTERS",
                                       description: "Pass email addresses of testers, separated by commas",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :testers_file,
                                       env_name: "FIREBASEAPPDISTRO_TESTERS_FILE",
                                       description: "Pass email addresses of testers, separated by commas",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :release_notes,
                                       env_name: "FIREBASEAPPDISTRO_RELEASE_NOTES",
                                       description: "Release notes for this build",
                                       default_value: Actions.lane_context[SharedValues::FL_CHANGELOG],
                                       default_value_dynamic: true,
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :release_notes_file,
                                       env_name: "FIREBASEAPPDISTRO_RELEASE_NOTES_FILE",
                                       description: "Release notes file for this build",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :firebase_cli_token,
                                       description: "Auth token for firebase cli",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :debug,
                                       description: "Print verbose debug output",
                                       optional: true,
                                       default_value: false,
                                       is_string: false)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end

      def self.example_code
        [
          <<-CODE
            firebase_app_distribution(
              app: "1:1234567890:ios:0a1b2c3d4e5f67890",
              testers: "snatchev@google.com, rebeccahe@google.com"
            )
          CODE
        ]
      end

      ## TODO: figure out if we can surpress color output.
      def self.is_firebasecmd_supported?(cmd)
        outerr, status = Open3.capture2e(cmd, "--non-interactive", FIREBASECMD_ACTION, "--help")
        return false unless status.success?

        if outerr =~ /is not a Firebase command/
          return false
        end

        true
      end

      def self.post_notes(app_id, release_id, release_notes)
        payload = { releaseNotes: { releaseNotes: release_notes } }
        if release_notes.nil? || release_notes.empty?
          UI.message("No release notes passed in. Skipping this step.")
          return
        end
        connection.post("#{v1_apps_path(app_id)}/releases/#{release_id}/notes", payload.to_json) do |request|
          request.headers["Authorization"] = "Bearer " + auth_token
        end
        UI.message("Release notes have been posted.")
      end

      def self.get_upload_token(app_id, binary_path)
        begin
          binary_hash = Digest::SHA256.hexdigest(File.open(binary_path).read)
        rescue Errno::ENOENT
          UI.crash!(ErrorMessage::APK_NOT_FOUND)
        end

        begin
          response = connection.get(v1_apps_path(app_id).to_s) do |request|
            request.headers["Authorization"] = "Bearer " + auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.crash!(ErrorMessage::INVALID_APP_ID)
        end

        contact_email = response.body[:contactEmail]
        if contact_email.nil? || contact_email.strip.empty?
          UI.crash!(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
        end
        return CGI.escape("projects/#{response.body[:projectNumber]}/apps/#{response.body[:appId]}/releases/-/binaries/#{binary_hash}")
      end

      def self.upload_binary(app_id, binary_path)
        connection.post("/app-binary-uploads?app_id=#{app_id}", File.open(binary_path).read) do |request|
          request.headers["Authorization"] = "Bearer " + auth_token
        end
      rescue Faraday::ResourceNotFound
        UI.crash!(ErrorMessage::INVALID_APP_ID)
      rescue Errno::ENOENT
        UI.crash!(ErrorMessage::APK_NOT_FOUND)
      end

      # Uploads the binary
      #
      # Returns the id of the release. Only happens on a successful release, on a fail release a messsage notifies the user.
      def self.upload(app_id, binary_path)
        upload_token = get_upload_token(app_id, binary_path)
        upload_status_response = get_upload_status(app_id, upload_token)
        if upload_status_response.success?
          UI.message("This APK/IPA has been uploaded before. Skipping upload step.")
        else
          UI.message("This APK has not been uploaded before.")
          MAX_POLLING_RETRIES.times do
            if upload_status_response.success?
              UI.message("Uploaded APK/IPA Successfully!")
              break
            elsif upload_status_response.in_progress?
              sleep(POLLING_INTERVAL_SECONDS)
            else
              UI.message("Uploading the APK/IPA.")
              upload_binary(app_id, binary_path)
            end
            upload_status_response = get_upload_status(app_id, upload_token)
          end
          unless upload_status_response.success?
            UI.message("It took longer than expected to process your APK/IPA, please try again")
          end
        end
        upload_status_response.release_id
      end

      # Gets the upload status for the app release
      #
      # Returns the status of the release. On success the release id exists and is nil in all other cases.
      def self.get_upload_status(app_id, app_token)
        begin
          response = connection.get("#{v1_apps_path(app_id)}/upload_status/#{app_token}") do |request|
            request.headers["Authorization"] = "Bearer " + auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.crash!(ErrorMessage::INVALID_APP_ID)
        end
        return UploadStatusResponse.new(response.body)
      end
    end
  end
end
