require 'fastlane_core/ui/ui'
require_relative '../helper/firebase_app_distribution_helper'

module Fastlane
  module Client
    class FirebaseAppDistributionApiClient
      include Helper::FirebaseAppDistributionHelper

      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_SECONDS = 5

      AUTHORIZATION = "Authorization"
      CONTENT_TYPE = "Content-Type"
      APPLICATION_OCTET_STREAM = "application/octet-stream"
      CLIENT_VERSION = "X-Client-Version"

      def initialize(auth_token, debug = false)
        @auth_token = auth_token
        @debug = debug
      end

      # Uploads the app binary to the Firebase API
      #
      # args
      #   app_name - Firebase App resource name
      #   binary_path - Absolute path to your app's aab/apk/ipa file
      #   platform - 'android' or 'ios'
      #   timeout - The amount of seconds before the upload will timeout, if not completed
      #
      # Returns the long-running operation name.
      #
      # Throws a user_error if the binary file does not exist
      def upload_binary(app_name, binary_path, platform, timeout)
        response = connection.post(binary_upload_url(app_name), read_binary(binary_path)) do |request|
          request.options.timeout = timeout # seconds
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_OCTET_STREAM
          request.headers[CLIENT_VERSION] = client_version_header_value
          request.headers["X-Goog-Upload-File-Name"] = File.basename(binary_path)
          request.headers["X-Goog-Upload-Protocol"] = "raw"
        end

        response.body[:name] || ''
      rescue Errno::ENOENT # Raised when binary_path file does not exist
        binary_type = binary_type_from_path(binary_path)
        UI.user_error!("#{ErrorMessage.binary_not_found(binary_type)}: #{binary_path}")
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

      def binary_upload_url(app_name)
        "/upload/v1/#{app_name}/releases:upload"
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

      def read_binary(path)
        # File must be read in binary mode to work on Windows
        File.open(path, 'rb').read
      end
    end
  end
end
