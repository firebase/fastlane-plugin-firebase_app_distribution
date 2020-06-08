require 'tempfile'
require 'fastlane/action'
require 'open3'
require 'shellwords'
require 'googleauth'
require_relative '../helper/firebase_app_distribution_helper'

## TODO: should always use a file underneath? I think so.
## How should we document the usage of release notes?
module Fastlane
  module Actions
    class FirebaseAppDistributionAction < Action
      DEFAULT_FIREBASE_CLI_PATH = `which firebase`
      FIREBASECMD_ACTION = "appdistribution:distribute".freeze
      CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
      CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"

      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        params.values
        get_app(params)
      ensure
        cleanup_tempfiles
      end

      def self.description
        "Release your beta builds with Firebase App Distribution"
      end

      def self.authors
        ["Manny Jimenez Github: mannyjimenez0810, Alonso Salas Infante Github: alonsosalasinfante"]
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

      def self.get_token
        client = Signet::OAuth2::Client.new(
          token_credential_uri: 'https://oauth2.googleapis.com/token',
          client_id: CLIENT_ID,
          client_secret: CLIENT_SECRET,
          refresh_token: ENV["FIREBASE_TOKEN"]
        )
        client.fetch_access_token!
        return client.access_token
      rescue Signet::AuthorizationError => error
        UI.crash!("Failed to retrieve FIREBASE_TOKEN")
      end

      def self.get_app(params)
        token = get_token

        # begin
        base_url = "https://firebaseappdistribution.googleapis.com"
        subD = "/v1alpha/apps/"
        appId = (params[:app]).to_s
        url = subD + appId

        connection = Faraday.new(url: base_url) do |conn|
          conn.response(:json, parser_options: { symbolize_names: true })
          conn.response(:raise_error)
          conn.adapter(Faraday.default_adapter)
        end

        response = connection.get(url) do |request|
          request.headers["Authorization"] = "Bearer " + token
        end

        contactEmail = response.body[:contactEmail]
        UI.message(contactEmail)

        if contactEmail.strip.empty?
          UI.error("Empty contact email")
        end
      rescue => error
        if error.class == Faraday::ResourceNotFound
          UI.crash!("Failed to onboard.")
        else
          UI.crash!("Failed to fetch app information")
        end
      end
    end
  end
end
