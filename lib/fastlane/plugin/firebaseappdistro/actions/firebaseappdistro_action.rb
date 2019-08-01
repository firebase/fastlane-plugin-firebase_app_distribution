require 'fastlane/action'
require_relative '../helper/firebaseappdistro_helper'

## TODO: should always use a file underneath? I think so.
## How should we document the usage of release notes?
module Fastlane
  module Actions
    class FirebaseappdistroAction < Action

      DEFAULT_FIREBASECMD = %x(which firebase).chomp

      def self.run(params)
        params.values # to validate all inputs before looking for the ipa/apk

        cmd = []
        cmd << params[:firebasecmd]
        cmd << "appdistribution:distribute"
        cmd << params[:ipa_path] || params[:apk_path]
        cmd << "--app #{params[:app]}"
        cmd << "--groups-file #{params[:groups]}"
        cmd << "--testers-file #{params[:testers]}"
        cmd << "--release-notes-file #{release_notes}"

        result = Actions.sh_control_output(
          cmd.join(" "),
          print_command: false,
          print_command_output: true, #TODO: if debug is set?
          error_callback: UI.user_error!
        )
      end

      def self.description
        "Release your beta builds to Firebase App Distro"
      end

      def self.authors
        ["Stefan Natchev"]
      end

      # supports markdown.
      def self.details
        "Release your beta builds to Firebase App Distro"
      end

      def self.release_notes
        Actions.lane_context[SharedValues::FL_CHANGELOG]
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
                                         UI.user_error!("Couldn't find ipa file at path '#{value}'") unless File.exist?(value)
                                       end),
          # Android Specific
          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       env_name: "FIREBASEAPPDISTRO_APK_PATH",
                                       description: "Path to your APK file",
                                       default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH] || apk_path_default,
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Couldn't find apk file at path '#{value}'") unless File.exist?(value)
                                       end),
                                       
          FastlaneCore::ConfigItem.new(key: :app,
                                       env_name: "FIREBASEAPPDISTRO_APP",
                                       description: "Your app's Firebase App ID. You can find the App ID in the Firebase console, on the General Settings page.",
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :firebasecmd,
                                       env_name: "FIREBASEAPPDISTRO_FIREBASECMD",
                                       description: "The full path of the firebase cli command.",
                                       default_value: DEFAULT_FIREBASECMD,
                                       default_value_dynamic: true,
                                       optional: true,
                                       type: String,
                                       verify_block: proc do |value|
                                         if value.to_s == "" || !File.exist?(value)
                                           UI.user_error!("firebasecmd: missing path to firebase cli tool. Please install firebase in $PATH or specify path.")
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

          FastlaneCore::ConfigItem.new(key: :release_notes_file,
                                       env_name: "FIREBASEAPPDISTRO_RELEASE_NOTES_FILE",
                                       description: "Release notes for this build.",
                                       optional: true,
                                       type: String,
                                       verify_block: proc do |value|
                                         unless File.exist?(value)
                                         end
                                       end),

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
            firebaseappdistro(
              app: "1:1234567890:ios:0a1b2c3d4e5f67890",
              testers: ""
            )
          CODE
        ]
      end
    end
  end
end
