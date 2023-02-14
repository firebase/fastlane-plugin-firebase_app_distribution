require 'fastlane/action'
require_relative '../client/firebase_app_distribution_api_client'
require_relative '../helper/firebase_app_distribution_auth_client'
require_relative '../helper/firebase_app_distribution_helper'

module Fastlane
  module Actions
    module SharedValues
      FIREBASE_APP_DISTRO_LATEST_RELEASE ||= :FIREBASE_APP_DISTRO_LATEST_RELEASE
    end
    class FirebaseAppDistributionGetLatestReleaseAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        auth_token = fetch_auth_token(params[:service_credentials_file], params[:firebase_cli_token])
        fad_api_client = Client::FirebaseAppDistributionApiClient.new(auth_token, params[:debug])

        UI.message("⏳ Fetching latest release for app #{params[:app]}...")

        releases = fad_api_client.list_releases(app_name_from_app_id(params[:app]), 1)[:releases] || []
        if releases.empty?
          latest_release = nil
          UI.important("No releases for app #{params[:app]} found in App Distribution. Returning nil and setting Actions.lane_context[SharedValues::FIREBASE_APP_DISTRO_LATEST_RELEASE].")
        else
          latest_release = releases[0]
          UI.success("✅ Latest release fetched successfully. Returning release and setting Actions.lane_context[SharedValues::FIREBASE_APP_DISTRO_LATEST_RELEASE].")
        end
        Actions.lane_context[SharedValues::FIREBASE_APP_DISTRO_LATEST_RELEASE] = latest_release
        return latest_release
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Fetches the latest release in Firebase App Distribution"
      end

      def self.details
        [
          "Fetches information about the most recently created release in App Distribution, including the version and release notes. Returns nil if no releases are found."
        ].join("\n")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app,
                                       env_name: "FIREBASEAPPDISTRO_APP",
                                       description: "Your app's Firebase App ID. You can find the App ID in the Firebase console, on the General Settings page",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :firebase_cli_token,
                                       description: "Auth token generated using Firebase CLI's login:ci command",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :service_credentials_file,
                                       description: "Path to Google service account json",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :debug,
                                       description: "Print verbose debug output",
                                       optional: true,
                                       default_value: false,
                                       is_string: false)
        ]
      end

      def self.output
        [
          ['FIREBASE_APP_DISTRO_LATEST_RELEASE', 'A hash representing the lastest release created in Firebase App Distribution']
        ]
      end

      def self.return_value
        "Hash representation of the lastest release created in Firebase App Distribution (see https://firebase.google.com/docs/reference/app-distribution/rest/v1/projects.apps.releases#resource:-release)"
      end

      def self.return_type
        :hash
      end

      def self.authors
        ["lkellogg@google.com"]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          'release = firebase_app_distribution_get_latest_release(app: "<your Firebase app ID>")',
          'increment_build_number({
            build_number: firebase_app_distribution_get_latest_release(app: "<your Firebase app ID>")[:buildVersion].to_i + 1
          })'
        ]
      end

      def self.sample_return_value
        {
          name: "projects/123456789/apps/1:1234567890:ios:0a1b2c3d4e5f67890/releases/0a1b2c3d4",
          releaseNotes: {
            text: "Here are some release notes!"
          },
          displayVersion: "1.2.3",
          buildVersion: "10",
          createTime: "2021-10-06T15:01:23Z"
        }
      end
    end
  end
end
