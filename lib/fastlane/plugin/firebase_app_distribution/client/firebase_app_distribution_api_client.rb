require 'fastlane_core/ui/ui'
require_relative '../helper/firebase_app_distribution_helper'

module Fastlane
  module Client
    class FirebaseAppDistributionApiClient
      include Helper::FirebaseAppDistributionHelper

      BASE_URL = "https://firebaseappdistribution.googleapis.com"

      AUTHORIZATION = "Authorization"
      CLIENT_VERSION = "X-Client-Version"

      def initialize(auth_token, debug = false)
        @auth_token = auth_token
        @debug = debug
      end

      # Get tester UDIDs
      #
      # args
      #   app_name - Firebase App resource name
      #
      # Returns a list of hashes containing tester device info
      def get_udids(app_id)
        begin
          response = connection.get(get_udids_url(app_id)) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
            request.headers[CLIENT_VERSION] = client_version_header_value
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        end
        response.body[:testerUdids] || []
      end

      private

      def client_version_header_value
        "fastlane/#{Fastlane::FirebaseAppDistribution::VERSION}"
      end

      def get_udids_url(app_id)
        "/v1alpha/apps/#{app_id}/testers:getTesterUdids"
      end

      def connection
        @connection ||= Faraday.new(url: BASE_URL) do |conn|
          conn.response(:json, parser_options: { symbolize_names: true })
          conn.response(:raise_error) # raise_error middleware will run before the json middleware
          conn.response(:logger, nil, { headers: false, bodies: { response: true }, log_level: :debug }) if @debug
          conn.adapter(Faraday.default_adapter)
        end
      end
    end
  end
end
