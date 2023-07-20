require 'fastlane_core/ui/ui'
require_relative '../client/error_response'
require_relative '../helper/firebase_app_distribution_helper'

module Fastlane
  module Client
    class FirebaseAppDistributionApiClient
      include Helper::FirebaseAppDistributionHelper

      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token"
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_SECONDS = 5

      AUTHORIZATION = "Authorization"
      CONTENT_TYPE = "Content-Type"
      APPLICATION_JSON = "application/json"
      APPLICATION_OCTET_STREAM = "application/octet-stream"
      CLIENT_VERSION = "X-Client-Version"

      def initialize(auth_token, debug = false)
        @auth_token = auth_token
        @debug = debug
      end

      # Enables tester access to the specified app release. Skips this
      # step if no testers are passed in (emails and group_aliases are nil/empty).
      #
      # args
      #   release_name - App release resource name, returned by upload_status endpoint
      #   emails - String array of app testers' email addresses
      #   group_aliases - String array of Firebase tester group aliases
      #
      # Throws a user_error if emails or group_aliases are invalid
      def distribute(release_name, emails, group_aliases)
        if (emails.nil? || emails.empty?) && (group_aliases.nil? || group_aliases.empty?)
          UI.success("✅ No testers passed in. Skipping this step.")
          return
        end
        payload = { testerEmails: emails, groupAliases: group_aliases }
        begin
          connection.post(distribute_url(release_name), payload.to_json) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
            request.headers[CONTENT_TYPE] = APPLICATION_JSON
            request.headers[CLIENT_VERSION] = client_version_header_value
          end
        rescue Faraday::ClientError
          UI.user_error!("#{ErrorMessage::INVALID_TESTERS} \nEmails: #{emails} \nGroup Aliases: #{group_aliases}")
        end
        UI.success("✅ Added testers/groups.")
      end

      # Update release notes for the specified app release. Skips this
      # step if no notes are passed in (release_notes is nil/empty).
      #
      # args
      #   release_name - App release resource name, returned by upload_status endpoint
      #   release_notes - String of notes for this release
      #
      # Returns a hash of the release
      #
      # Throws a user_error if the release_notes are invalid
      def update_release_notes(release_name, release_notes)
        payload = {
          name: release_name,
          releaseNotes: {
            text: release_notes
          }
        }
        response = connection.patch(update_release_notes_url(release_name), payload.to_json) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_JSON
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
        UI.success("✅ Posted release notes.")
        response.body
      rescue Faraday::ClientError => e
        error = ErrorResponse.new(e.response)
        UI.user_error!("#{ErrorMessage::INVALID_RELEASE_NOTES}: #{error.message}")
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

      def v1alpha_apps_url(app_id)
        "/v1alpha/apps/#{app_id}"
      end

      def v1_apps_url(app_name)
        "/v1/#{app_name}"
      end

      def distribute_url(release_name)
        "/v1/#{release_name}:distribute"
      end

      def get_udids_url(app_id)
        "#{v1alpha_apps_url(app_id)}/testers:getTesterUdids"
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
