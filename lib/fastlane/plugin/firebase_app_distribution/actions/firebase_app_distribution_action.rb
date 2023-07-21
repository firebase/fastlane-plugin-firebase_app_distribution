require 'fastlane/action'
require 'open3'
require 'shellwords'
require 'googleauth'
require_relative '../helper/firebase_app_distribution_helper'
require_relative '../helper/firebase_app_distribution_error_message'
require_relative '../client/firebase_app_distribution_api_client'
require_relative '../helper/firebase_app_distribution_auth_client'

## How should we document the usage of release notes?
module Fastlane
  module Actions
    module SharedValues
      FIREBASE_APP_DISTRO_RELEASE ||= :FIREBASE_APP_DISTRO_RELEASE
    end

    class FirebaseAppDistributionAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      DEFAULT_UPLOAD_TIMEOUT_SECONDS = 300
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_SECONDS = 5

      def self.run(params)
        params.values # to validate all inputs before looking for the ipa/apk/aab

        app_id = app_id_from_params(params)
        app_name = app_name_from_app_id(app_id)
        platform = lane_platform || platform_from_app_id(app_id)

        binary_path = get_binary_path(platform, params)
        UI.user_error!("Couldn't find binary") if binary_path.nil?
        UI.user_error!("Couldn't find binary at path #{binary_path}") unless File.exist?(binary_path)
        binary_type = binary_type_from_path(binary_path)

        client = init_client(params[:service_credentials_file], params[:firebase_cli_token], params[:debug])
        # TODO(tundeagboola) delete when all instances are replaced with generated client
        fad_api_client = Client::FirebaseAppDistributionApiClient.new(client.authorization.access_token, params[:debug])

        # If binary is an AAB, get the AAB info for this app, which includes the integration state and certificate data
        if binary_type == :AAB
          aab_info = client.get_project_app_aab_info(aab_info_name(app_name))
          validate_aab_setup!(aab_info)
        end

        binary_type = binary_type_from_path(binary_path)
        UI.message("⌛ Uploading the #{binary_type}.")

        timeout = get_upload_timeout(params)
        operation = upload_binary(app_name, binary_path, client, timeout)
        release = poll_upload_release_operation(client, operation, binary_type)

        if binary_type == :AAB && aab_info && !aab_certs_included?(aab_info.test_certificate)
          updated_aab_info = client.get_project_app_aab_info(aab_info_name(app_name))
          if aab_certs_included?(updated_aab_info.test_certificate)
            UI.message("After you upload an AAB for the first time, App Distribution " \
              "generates a new test certificate. All AAB uploads are re-signed with this test " \
              "certificate. Use the certificate fingerprints below to register your app " \
              "signing key with API providers, such as Google Sign-In and Google Maps.\n" \
              "MD-1 certificate fingerprint: #{updated_aab_info.test_certificate.hash_md5}\n" \
              "SHA-1 certificate fingerprint: #{updated_aab_info.test_certificate.hash_sha1}\n" \
              "SHA-256 certificate fingerprint: #{updated_aab_info.test_certificate.hash_sha256}")
          end
        end

        release_notes = release_notes(params)
        if release_notes.nil? || release_notes.empty?
          UI.message("⏩ No release notes passed in. Skipping this step.")
        else
          release.release_notes = Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1ReleaseNotes.new(
            text: release_notes
          )
          release = client.patch_project_app_release(release.name, release)
        end

        testers = get_value_from_value_or_file(params[:testers], params[:testers_file])
        groups = get_value_from_value_or_file(params[:groups], params[:groups_file])
        emails = string_to_array(testers)
        group_aliases = string_to_array(groups)
        fad_api_client.distribute(release.name, emails, group_aliases)
        UI.success("🎉 App Distribution upload finished successfully. Setting Actions.lane_context[SharedValues::FIREBASE_APP_DISTRO_RELEASE] to the uploaded release.")

        if release.firebase_console_uri
          UI.message("🔗 View this release in the Firebase console: #{release.firebase_console_uri}")
        end

        if release.testing_uri
          UI.message("🔗 Share this release with testers who have access: #{release.testing_uri}")
        end

        if release.binary_download_uri
          UI.message("🔗 Download the release binary (link expires in 1 hour): #{release.binary_download_uri}")
        end

        Actions.lane_context[SharedValues::FIREBASE_APP_DISTRO_RELEASE] = deep_symbolize_keys(JSON.parse(release.to_json))
        release
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

      def self.get_upload_timeout(params)
        if params[:upload_timeout]
          return params[:upload_timeout]
        else
          return DEFAULT_UPLOAD_TIMEOUT_SECONDS
        end
      end

      def self.validate_aab_setup!(aab_info)
        if aab_info && aab_info.integration_state != 'INTEGRATED' && aab_info.integration_state != 'AAB_STATE_UNAVAILABLE'
          case aab_info.integration_state
          when 'PLAY_ACCOUNT_NOT_LINKED'
            UI.user_error!(ErrorMessage::PLAY_ACCOUNT_NOT_LINKED)
          when 'APP_NOT_PUBLISHED'
            UI.user_error!(ErrorMessage::APP_NOT_PUBLISHED)
          when 'NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT'
            UI.user_error!(ErrorMessage::NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT)
          when 'PLAY_IAS_TERMS_NOT_ACCEPTED'
            UI.user_error!(ErrorMessage::PLAY_IAS_TERMS_NOT_ACCEPTED)
          else
            UI.user_error!(ErrorMessage.aab_upload_error(aab_info.integration_state))
          end
        end
      end

      def self.aab_certs_included?(test_certificate)
        present?(test_certificate.hash_md5) && present?(test_certificate.hash_sha1) &&
          present?(test_certificate.hash_sha256)
      end

      def self.aab_info_name(app_name)
        "#{app_name}/aabInfo"
      end

      def self.release_notes(params)
        release_notes_param =
          get_value_from_value_or_file(params[:release_notes], params[:release_notes_file])
        release_notes_param || Actions.lane_context[SharedValues::FL_CHANGELOG]
      end

      def self.poll_upload_release_operation(client, operation, binary_type)
        operation = client.get_project_app_release_operation(operation.name)
        MAX_POLLING_RETRIES.times do
          if operation.done && operation.response && operation.response['release']
            release = extract_release(operation)
            result = operation.response['result']
            if result == 'RELEASE_UPDATED'
              UI.success("✅ Uploaded #{binary_type} successfully; updated provisioning profile of existing release #{release_version(release)}.")
              break
            elsif result == 'RELEASE_UNMODIFIED'
              UI.success("✅ The same #{binary_type} was found in release #{release_version(release)} with no changes, skipping.")
              break
            else
              UI.success("✅ Uploaded #{binary_type} successfully and created release #{release_version(release)}.")
            end
            break
          elsif !operation.done
            sleep(POLLING_INTERVAL_SECONDS)
            operation = client.get_project_app_release_operation(operation.name)
          else
            if operation.error && operation.error.message
              UI.user_error!("#{ErrorMessage.upload_binary_error(binary_type)}: #{operation.error.message}")
            else
              UI.user_error!(ErrorMessage.upload_binary_error(binary_type))
            end
          end
        end
        extract_release(operation)
      end

      def self.upload_binary(app_name, binary_path, client, timeout)
        options = Google::Apis::RequestOptions.new
        options.max_elapsed_time = timeout
        options.header = {
          'Content-Type' => 'application/octet-stream',
          'X-Goog-Upload-File-Name' => File.basename(binary_path),
          'X-Goog-Upload-Protocol' => 'raw'
        }
        # For some reason calling the client.upload_medium returns nil when
        # it should return a long running operation object, so we make a
        # standard http call instead and convert it to a long running object
        # https://github.com/googleapis/google-api-ruby-client/blob/main/generated/google-apis-firebaseappdistribution_v1/lib/google/apis/firebaseappdistribution_v1/service.rb#L79
        # TODO(kbolay) Prefer client.upload_medium
        response = client.http(
          :post,
          "https://firebaseappdistribution.googleapis.com/upload/v1/#{app_name}/releases:upload",
          body: File.open(binary_path, 'rb').read,
          options: options
        )

        Google::Apis::FirebaseappdistributionV1::GoogleLongrunningOperation.from_json(response)
      end

      def self.extract_release(operation)
        Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1Release.from_json(operation.response['release'].to_json)
      end

      def self.release_version(release)
        if release.display_version && release.build_version
          "#{release.display_version} (#{release.build_version})"
        elsif release.display_version
          release.display_version
        else
          release.build_version
        end
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
                                         UI.user_error!("firebase_app_distribution: '#{value}' is not a valid value for android_artifact_type. Should be 'APK' or 'AAB'") unless ['APK', 'AAB'].include?(value)
                                       end),
          # Generic
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
                                       description: "The group aliases used for distribution, separated by commas",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :groups_file,
                                       env_name: "FIREBASEAPPDISTRO_GROUPS_FILE",
                                       description: "The group aliases used for distribution, separated by commas",
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
                                       description: "Auth token generated using the Firebase CLI's login:ci command",
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
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :upload_timeout,
                                       description: "The amount of seconds before the upload will timeout, if not completed",
                                       optional: true,
                                       default_value: DEFAULT_UPLOAD_TIMEOUT_SECONDS,
                                       type: Integer)
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
              app: "<your Firebase app ID>",
              testers: "snatchev@google.com, rebeccahe@google.com"
            )
          CODE
        ]
      end

      def self.output
        [
          ['FIREBASE_APP_DISTRO_RELEASE', 'A hash representing the uploaded release created in Firebase App Distribution']
        ]
      end
    end
  end
end
