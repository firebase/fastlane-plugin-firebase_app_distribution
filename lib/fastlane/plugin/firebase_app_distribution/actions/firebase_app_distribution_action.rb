require 'fastlane/action'
require 'open3'
require 'shellwords'
require 'googleauth'
require_relative '../helper/upload_status_response'
require_relative '../helper/firebase_app_distribution_helper'
require_relative '../helper/firebase_app_distribution_error_message'
require_relative '../client/firebase_app_distribution_api_client'
require_relative '../helper/firebase_app_distribution_auth_client'

## How should we document the usage of release notes?
module Fastlane
  module Actions
    class FirebaseAppDistributionAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        params.values # to validate all inputs before looking for the ipa/apk/aab

        app_id = app_id_from_params(params)
        platform = lane_platform || platform_from_app_id(app_id)

        binary_path = get_binary_path(platform, params)
        UI.user_error!("Couldn't find binary") if binary_path.nil?
        UI.user_error!("Couldn't find binary at path #{binary_path}") unless File.exist?(binary_path)
        binary_type = binary_type_from_path(binary_path)

        auth_token = fetch_auth_token(params[:service_credentials_file], params[:firebase_cli_token])
        fad_api_client = Client::FirebaseAppDistributionApiClient.new(auth_token, params[:debug])

        # If binary is an AAB get FULL view of app which includes the aab_state
        app_view = binary_type == :AAB ? 'FULL' : 'BASIC'
        app = fad_api_client.get_app(app_id, app_view)
        validate_app!(app, binary_type)
        release_id = fad_api_client.upload(app.project_number, app_id, binary_path, platform.to_s)

        if binary_type == :AAB && app.aab_certificate.empty?
          updated_app = fad_api_client.get_app(app_id)
          unless updated_app.aab_certificate.empty?
            UI.message("After you upload an AAB for the first time, App Distribution " \
              "generates a new test certificate. All AAB uploads are re-signed with this test " \
              "certificate. Use the certificate fingerprints below to register your app " \
              "signing key with API providers, such as Google Sign-In and Google Maps.\n" \
              "MD-1 certificate fingerprint: #{updated_app.aab_certificate.md5_certificate_hash}\n" \
              "SHA-1 certificate fingerprint: #{updated_app.aab_certificate.sha1_certificate_hash}\n" \
              "SHA-256 certificate fingerprint: #{updated_app.aab_certificate.sha256_certificate_hash}")
          end
        end

        fad_api_client.post_notes(app_id, release_id, release_notes(params))

        testers = get_value_from_value_or_file(params[:testers], params[:testers_file])
        groups = get_value_from_value_or_file(params[:groups], params[:groups_file])
        emails = string_to_array(testers)
        group_ids = string_to_array(groups)
        fad_api_client.enable_access(app_id, release_id, emails, group_ids)
        UI.success("🎉 App Distribution upload finished successfully.")
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

      def self.app_id_from_params(params)
        if params[:app]
          app_id = params[:app]
        elsif xcode_archive_path
          plist_path = params[:googleservice_info_plist_path]
          app_id = get_ios_app_id_from_archive_plist(xcode_archive_path, plist_path)
        end
        if app_id.nil?
          UI.crash!(ErrorMessage::MISSING_APP_ID)
        end
        app_id
      end

      def self.xcode_archive_path
        # prevents issues on cross-platform build environments where an XCode build happens within
        # the same lane
        return nil if lane_platform == :android

        Actions.lane_context[SharedValues::XCODEBUILD_ARCHIVE]
      end

      def self.lane_platform
        Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]
      end

      def self.platform_from_app_id(app_id)
        if app_id.include?(':ios:')
          :ios
        elsif app_id.include?(':android:')
          :android
        end
      end

      def self.get_binary_path(platform, params)
        if platform == :ios
          return params[:ipa_path] ||
                 Actions.lane_context[SharedValues::IPA_OUTPUT_PATH] ||
                 Dir["*.ipa"].sort_by { |x| File.mtime(x) }.last
        end

        if platform == :android
          return params[:apk_path] || params[:android_artifact_path] if params[:apk_path] || params[:android_artifact_path]

          if params[:android_artifact_type] == 'AAB'
            return Actions.lane_context[SharedValues::GRADLE_AAB_OUTPUT_PATH] ||
                   Dir["*.aab"].last ||
                   Dir[File.join("app", "build", "outputs", "bundle", "release", "app-release.aab")].last
          end

          return Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH] ||
                 Dir["*.apk"].last ||
                 Dir[File.join("app", "build", "outputs", "apk", "release", "app-release.apk")].last
        end
      end

      def self.validate_app!(app, binary_type)
        if app.contact_email.nil? || app.contact_email.strip.empty?
          UI.user_error!(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
        end

        if binary_type == :AAB && app.aab_state != App::AabState::ACTIVE && app.aab_state != App::AabState::UNAVAILABLE
          case app.aab_state
          when App::AabState::PLAY_ACCOUNT_NOT_LINKED
            UI.user_error!(ErrorMessage::PLAY_ACCOUNT_NOT_LINKED)
          when App::AabState::APP_NOT_PUBLISHED
            UI.user_error!(ErrorMessage::APP_NOT_PUBLISHED)
          when App::AabState::NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT
            UI.user_error!(ErrorMessage::NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT)
          when App::AabState::PLAY_IAS_TERMS_NOT_ACCEPTED
            UI.user_error!(ErrorMessage::PLAY_IAS_TERMS_NOT_ACCEPTED)
          else
            UI.user_error!(ErrorMessage.aab_upload_error(app.aab_state))
          end
        end
      end

      def self.release_notes(params)
        release_notes_param =
          get_value_from_value_or_file(params[:release_notes], params[:release_notes_file])
        release_notes_param || Actions.lane_context[SharedValues::FL_CHANGELOG]
      end

      def self.available_options
        [
          # iOS Specific
          FastlaneCore::ConfigItem.new(key: :ipa_path,
                                       env_name: "FIREBASEAPPDISTRO_IPA_PATH",
                                       description: "Path to your IPA file. Optional if you use the _gym_ or _xcodebuild_ action",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :googleservice_info_plist_path,
                                       env_name: "GOOGLESERVICE_INFO_PLIST_PATH",
                                       description: "Path to your GoogleService-Info.plist file, relative to the archived product path",
                                       default_value: "GoogleService-Info.plist",
                                       optional: true,
                                       type: String),
          # Android Specific
          FastlaneCore::ConfigItem.new(key: :apk_path,
                                       env_name: "FIREBASEAPPDISTRO_APK_PATH",
                                       description: "Path to your APK file",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :android_artifact_path,
                                       env_name: "FIREBASEAPPDISTRO_ANDROID_ARTIFACT_PATH",
                                       description: "Path to your APK or AAB file",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :android_artifact_type,
                                       env_name: "FIREBASEAPPDISTRO_ANDROID_ARTIFACT_TYPE",
                                       description: "Android artifact type. Set to 'APK' or 'AAB'. Defaults to 'APK' if not set",
                                       default_value: "APK",
                                       default_value_dynamic: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("firebase_app_distribution: '#{value}' is not a valid value for android_artifact_path. Should be 'APK' or 'AAB'") unless ['APK', 'AAB'].include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :app,
                                       env_name: "FIREBASEAPPDISTRO_APP",
                                       description: "Your app's Firebase App ID. You can find the App ID in the Firebase console, on the General Settings page",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :firebase_cli_path,
                                       deprecated: "This plugin no longer uses the Firebase CLI",
                                       env_name: "FIREBASEAPPDISTRO_FIREBASE_CLI_PATH",
                                       description: "The absolute path of the firebase cli command",
                                       type: String),
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
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :service_credentials_file,
                                       description: "Path to Google service account json",
                                       optional: true,
                                       type: String)
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
    end
  end
end
