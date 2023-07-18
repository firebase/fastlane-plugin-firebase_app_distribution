require 'fastlane/action'
require 'fastlane_core/ui/ui'

require_relative '../helper/firebase_app_distribution_helper'
require_relative '../helper/firebase_app_distribution_auth_client'

module Fastlane
  module Actions
    class FirebaseAppDistributionCreateGroupAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        auth_token = fetch_auth_token(params[:service_credentials_file], params[:firebase_cli_token])
        fad_api_client = Client::FirebaseAppDistributionApiClient.new(auth_token, params[:debug])

        if blank?(params[:alias])
          UI.user_error!("Must specify `alias`.")
        end

        if blank?(params[:display_name])
          UI.user_error!("Must specify `display_name`.")
        end

        project_number = params[:project_number]
        group_alias = params[:alias]
        display_name = params[:display_name]

        UI.message("⏳ Creating tester group '#{group_alias} (#{display_name})' in project #{project_number}...")

        fad_api_client.create_group(project_number, group_alias, display_name)

        UI.success("✅ Group created successfully.")
      end

      def self.description
        "Create a tester group"
      end

      def self.authors
        ["Garry Jeromson"]
      end

      # supports markdown.
      def self.details
        "Create a tester group"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :project_number,
                                       env_name: "FIREBASEAPPDISTRO_PROJECT_NUMBER",
                                       description: "Your Firebase project number. You can find the project number in the Firebase console, on the General Settings page",
                                       type: Integer,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :alias,
                                       env_name: "FIREBASEAPPDISTRO_CREATE_GROUP_ALIAS",
                                       description: "Alias of the group to be created",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :display_name,
                                       env_name: "FIREBASEAPPDISTRO_CREATE_GROUP_DISPLAY_NAME",
                                       description: "Display name for the group to be created",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :service_credentials_file,
                                       description: "Path to Google service credentials file",
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
                                       is_string: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
