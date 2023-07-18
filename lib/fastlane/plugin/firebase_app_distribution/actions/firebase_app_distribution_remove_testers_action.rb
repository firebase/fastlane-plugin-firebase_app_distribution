require 'fastlane/action'
require 'fastlane_core/ui/ui'

require_relative '../helper/firebase_app_distribution_helper'
require_relative '../helper/firebase_app_distribution_auth_client'

module Fastlane
  module Actions
    class FirebaseAppDistributionRemoveTestersAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        auth_token = fetch_auth_token(params[:service_credentials_file], params[:firebase_cli_token])
        fad_api_client = Client::FirebaseAppDistributionApiClient.new(auth_token, params[:debug])

        if blank?(params[:emails]) && blank?(params[:file])
          UI.user_error!("Must specify `emails` or `file`.")
        end

        emails = string_to_array(get_value_from_value_or_file(params[:emails], params[:file]))

        UI.user_error!("Must pass at least one email") if blank?(emails)

        if emails.count > 1000
          UI.user_error!("A maximum of 1000 testers can be removed at a time.")
        end

        if blank?(params[:group_alias])
          UI.message("⏳ Removing #{emails.count} testers from project #{params[:project_number]}...")
          count = fad_api_client.remove_testers(params[:project_number], emails)
          UI.success("✅ #{count} tester(s) removed successfully.")
        else
          UI.message("⏳ Removing #{emails.count} testers from group #{params[:group_alias]}...")
          fad_api_client.remove_testers_from_group(params[:project_number], params[:group_alias], emails)
          UI.success("✅ Tester(s) removed successfully.")
        end
      end

      def self.description
        "Delete testers in bulk from a comma-separated list or a file"
      end

      def self.authors
        ["Tunde Agboola"]
      end

      # supports markdown.
      def self.details
        "Delete testers in bulk from a comma-separated list or a file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :project_number,
                                      env_name: "FIREBASEAPPDISTRO_PROJECT_NUMBER",
                                      description: "Your Firebase project number. You can find the project number in the Firebase console, on the General Settings page",
                                      type: Integer,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :emails,
                                      env_name: "FIREBASEAPPDISTRO_REMOVE_TESTERS_EMAILS",
                                      description: "Comma separated list of tester emails to be deleted (or removed from a group if a group alias is specified). A maximum of 1000 testers can be deleted/removed at a time",
                                      optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :file,
                                      env_name: "FIREBASEAPPDISTRO_REMOVE_TESTERS_FILE",
                                      description: "Path to a file containing a comma separated list of tester emails to be deleted (or removed from a group if a group alias is specified). A maximum of 1000 testers can be deleted/removed at a time",
                                      optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :group_alias,
                                       env_name: "FIREBASEAPPDISTRO_REMOVE_TESTERS_GROUP_ALIAS",
                                       description: "Alias of the group to remove the specified testers from. Testers will not be deleted from the project",
                                       optional: true,
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
