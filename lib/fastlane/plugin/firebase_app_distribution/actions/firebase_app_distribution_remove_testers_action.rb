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

        emails = get_value_from_value_or_file(params[:emails], params[:file]).split(',')

        if emails.count > 1000
          UI.user_error!("A maximum of 1000 testers can be removed at a time.")
        end

        count = fad_api_client.remove_testers(params[:project], emails)

        UI.success("✅ #{count} tester(s) removed successfully.")
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
          FastlaneCore::ConfigItem.new(key: :project,
                                      env_name: "FIREBASEAPPDISTRO_PROJECT_NUMBER",
                                      description: "Your Firebase project number. You can find the project number in the Firebase console, on the General Settings page",
                                      type: Integer),
          FastlaneCore::ConfigItem.new(key: :emails,
                                      env_name: "FIREBASEAPPDISTRO_REMOVE_TESTERS_EMAILS",
                                      description: "Comma separated list of tester emails to be deleted. A maximum of 1000 testers can be deleted at a time",
                                      optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :file,
                                      env_name: "FIREBASEAPPDISTRO_REMOVE_TESTERS_FILE",
                                      description: "Path to a file containing a comma separated list of tester emails to be deleted. A maximum of 1000 testers can be deleted at a time",
                                      optional: true,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :service_credentials_file,
                                      description: "Path to Google service credentials file",
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
    end
  end
end