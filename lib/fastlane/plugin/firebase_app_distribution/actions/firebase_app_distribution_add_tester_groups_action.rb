require 'fastlane/action'
require 'fastlane_core/ui/ui'
require 'json'
require 'json-schema'

require_relative '../helper/firebase_app_distribution_helper'
require_relative '../helper/firebase_app_distribution_auth_client'

module Fastlane
  module Actions
    class FirebaseAppDistributionAddTesterGroupsAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        auth_token = fetch_auth_token(params[:service_credentials_file], params[:firebase_cli_token])
        fad_api_client = Client::FirebaseAppDistributionApiClient.new(auth_token, params[:debug])

        if blank?(params[:file])
          UI.user_error!("Must specify `file`.")
        end

        json_file = params[:file]

        # Read the JSON file
        begin
          json_data = File.open(json_file).read
        rescue Errno::ENOENT => _
          UI.user_error!("JSON file not found: #{json_file}")
          return
        end

        tester_group_data = JSON.parse(json_data)

        begin
          JSON::Validator.validate!(GROUPS_JSON_SCHEMA, tester_group_data)
        rescue JSON::Schema::ValidationError => e
          UI.user_error!("Invalid JSON file content. #{e.message}")
        end

        groups = tester_group_data["groups"]
        groups.each do |group|
          group_alias = group['alias']
          group_display_name = group["displayName"]
          UI.message("⏳ Creating tester group '#{group_alias}' testers in project #{params[:project_number]}...")

          fad_api_client.create_group(params[:project_number], group_alias, group_display_name)

          testers = group["testers"]
          UI.message("⏳ Adding #{testers.count} testers to group #{group_alias}...")

          fad_api_client.add_testers_to_group(params[:project_number], group_alias, testers)
          UI.message("Testers successfully added to group(s).")
        end

        UI.success("✅ Tester group(s) successfully added.")
      end

      def self.description
        "Create tester groups and testers in bulk from a JSON file"
      end

      def self.authors
        ["Garry Jeromson"]
      end

      # supports markdown.
      def self.details
        "Create tester groups and testers in bulk from a JSON file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :project_number,
                                       env_name: "FIREBASEAPPDISTRO_PROJECT_NUMBER",
                                       description: "Your Firebase project number. You can find the project number in the Firebase console, on the General Settings page",
                                       type: Integer,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :file,
                                       env_name: "FIREBASEAPPDISTRO_ADD_TESTER_GROUPS_FILE",
                                       description: "Path to a JSON file containing tester groups and tester emails to be created. A maximum of 1000 testers can be created at a time",
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
