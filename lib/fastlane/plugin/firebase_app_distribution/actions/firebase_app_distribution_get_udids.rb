require 'fastlane/action'
require 'open3'
require 'shellwords'
require 'googleauth'
require_relative '../helper/firebase_app_distribution_helper'
require_relative '../helper/firebase_app_distribution_error_message'
require_relative '../client/firebase_app_distribution_api_client'
require_relative '../helper/firebase_app_distribution_auth_client'

module Fastlane
  module Actions
    class FirebaseAppDistributionGetUdidsAction < Action
      extend Auth::FirebaseAppDistributionAuthClient
      extend Helper::FirebaseAppDistributionHelper

      def self.run(params)
        client = init_client(params[:service_credentials_file], params[:firebase_cli_token], params[:debug])
        fad_api_client = Client::FirebaseAppDistributionApiClient.new(client.authorization.access_token, params[:debug])

        app_id = params[:app]
        udids = fad_api_client.get_udids(app_id)

        if udids.empty?
          UI.important("App Distribution fetched 0 tester UDIDs. Nothing written to output file.")
        else
          write_udids_to_file(udids, params[:output_file])
          UI.success("🎉 App Distribution tester UDIDs written to: #{params[:output_file]}")
        end
      end

      def self.write_udids_to_file(udids, output_file)
        File.open(output_file, 'w') do |f|
          f.write("Device ID\tDevice Name\tDevice Platform\n")
          udids.each do |tester_udid|
            f.write("#{tester_udid[:udid]}\t#{tester_udid[:name]}\t#{tester_udid[:platform]}\n")
          end
        end
      end

      def self.description
        "Download the UDIDs of your Firebase App Distribution testers"
      end

      def self.authors
        ["Lee Kellogg"]
      end

      # supports markdown.
      def self.details
        "Export your testers' device identifiers in a CSV file, so you can add them your provisioning profile. This file can be imported into your Apple developer account using the Register Multiple Devices option. See the [App Distribution docs](https://firebase.google.com/docs/app-distribution/ios/distribute-console#register-tester-devices) for more info."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app,
                                       env_name: "FIREBASEAPPDISTRO_APP",
                                       description: "Your app's Firebase App ID. You can find the App ID in the Firebase console, on the General Settings page",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :output_file,
                                       env_name: "FIREBASEAPPDISTRO_OUTPUT_FILE",
                                       description: "The path to the file where the tester UDIDs will be written",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :firebase_cli_token,
                                       description: "Auth token generated using the Firebase CLI's login:ci command",
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

      def self.is_supported?(platform)
        [:ios].include?(platform)
      end

      def self.example_code
        [
          <<-CODE
            firebase_app_distribution_get_udids(
              app: "<your Firebase app ID>",
              output_file: "tester_udids.txt",
            )
          CODE
        ]
      end
    end
  end
end
