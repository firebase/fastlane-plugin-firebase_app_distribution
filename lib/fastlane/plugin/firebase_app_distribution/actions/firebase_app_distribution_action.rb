require 'tempfile'
require 'fastlane/action'
require 'open3'
require 'shellwords'
require 'googleauth'
require_relative './firebase_app_distribution_login'
require_relative '../helper/firebase_app_distribution_helper'

## TODO: should always use a file underneath? I think so.
## How should we document the usage of release notes?
module Fastlane
  module Actions
    class FirebaseAppDistributionAction < Action
      DEFAULT_FIREBASE_CLI_PATH = `which firebase`
      FIREBASECMD_ACTION = "appdistribution:distribute".freeze
      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      PATH = "/v1alpha/apps/"
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_S = 2

      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        params.values # to validate all inputs before looking for the ipa/apk
        upload_token = get_upload_token(params[:app], params[:apk_path])
        begin
          MAX_POLLING_RETRIES.times do
            status = upload_status(upload_token, params[:app])
            if status == "SUCCESS"
              UI.message("App Uploaded Successfully!") # Probably want something like it had before of apk has already been uploaded so no need to upload again
              break
            elsif status == "IN_PROGRESS"
              sleep(POLLING_INTERVAL_S)
            else
              UI.message("Uploading APK")
              begin
                upload_binary(params[:app], params[:apk_path])
              rescue => error
                UI.message("Failed to upload APK: " + error.message)
              end
            end
          end
        rescue
          UI.error("It took longer than expected to process your APK, please try again") # Same error message as Gradle plugin
        end
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

      def self.auth_token
        @auth_token ||= begin
          client = Signet::OAuth2::Client.new(
            token_credential_uri: 'https://oauth2.googleapis.com/token',
            client_id: FirebaseAppDistributionLoginAction::CLIENT_ID,
            client_secret: FirebaseAppDistributionLoginAction::CLIENT_SECRET,
            refresh_token: ENV["FIREBASE_TOKEN"]
          )
          client.fetch_access_token!
          return client.access_token
        rescue Signet::AuthorizationError => error
          UI.crash!("Wrong value for FIREBASE_TOKEN")
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

      def self.get_upload_token(app_id, binary_path)
        binary_hash = Digest::SHA256.hexdigest(File.open(binary_path).read)
        begin
          response = connection.get("#{PATH}#{app_id}") do |request|
            request.headers["Authorization"] = "Bearer " + auth_token
          end
        rescue Faraday::ResourceNotFound => error
          UI.user_error!(unknown_app_error(app_id))
        rescue => error
          UI.crash!("Failed to fetch app information: #{error.message}")
        end
        contact_email = response.body[:contactEmail]
        if contact_email.strip.empty?
          UI.user_error!("We could not find a contact email for app #{app_id}. Please visit App Distribution within the Firebase Console to set one up.")
        end
        return CGI.escape("projects/#{response.body[:projectNumber]}/apps/#{response.body[:appId]}/releases/-/binaries/#{binary_hash}")
      end

      def self.upload_binary(app_id, binary_path)
        begin
          response = connection.post("/app-binary-uploads?app_id=#{app_id}", File.open(binary_path).read) do |request|
            request.headers["Authorization"] = "Bearer " + auth_token
          end
        rescue Faraday::ResourceNotFound => error
          UI.user_error!(unknown_app_error(app_id))
        end
      end

      def self.upload_status(app_token, app_id)
        begin
          response = connection.get("#{PATH}#{app_id}/upload_status/#{app_token}") do |request|
            request.headers["Authorization"] = "Bearer " + auth_token
          end
        rescue Faraday::ResourceNotFound => error
          UI.user_error!(unknown_app_error(app_id))
        end
          response.body[:status]
      end

      def self.unknown_app_error(app_id)
        "App Distribution could not find your app #{app_id}. Make sure to onboard your app by pressing the \"Get started\" button on the App Distribution page in the Firebase console: https://console.firebase.google.com/project/_/appdistribution"
      end
    end
  end
end
