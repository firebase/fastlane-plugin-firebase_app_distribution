require 'fastlane_core/ui/ui'
require_relative '../actions/firebase_app_distribution_login'
require_relative '../client/error_response'
require_relative '../client/aab_info'
require_relative '../helper/firebase_app_distribution_helper'

module Fastlane
  module Client
    class FirebaseAppDistributionApiClient
      include Helper::FirebaseAppDistributionHelper

      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token"
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_SECONDS = 2

      AUTHORIZATION = "Authorization"
      CONTENT_TYPE = "Content-Type"
      APPLICATION_JSON = "application/json"
      APPLICATION_OCTET_STREAM = "application/octet-stream"

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
          end
        rescue Faraday::ClientError
          UI.user_error!("#{ErrorMessage::INVALID_TESTERS} \nEmails: #{emails} \nGroups: #{group_aliases}")
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
      # Throws a user_error if the release_notes are invalid
      def update_release_notes(release_name, release_notes)
        if release_notes.nil? || release_notes.empty?
          UI.success("✅ No release notes passed in. Skipping this step.")
          return
        end
        begin
          payload = {
            release: {
              name: release_name,
              releaseNotes: {
                text: release_notes
              }
            },
            updateMask: "release_notes.text"
          }
          connection.patch(update_release_notes_url(release_name), payload.to_json) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
            request.headers[CONTENT_TYPE] = APPLICATION_JSON
          end
        rescue Faraday::ClientError => e
          error = ErrorResponse.new(e.response)
          UI.user_error!("#{ErrorMessage::INVALID_RELEASE_NOTES}: #{error.message}")
        end
        UI.success("✅ Posted release notes.")
      end

      # Get AAB info (Android apps only)
      #
      # args
      #   app_name - Firebase App resource name
      #
      # Throws a user_error if the app hasn't been onboarded to App Distribution
      def get_aab_info(app_name)
        begin
          response = connection.get(aab_info_url(app_name)) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_name}")
        end

        AabInfo.new(response.body)
      end

      # Uploads the app binary to the Firebase API
      #
      # args
      #   app_name - Firebase App resource name
      #   binary_path - Absolute path to your app's aab/apk/ipa file
      #   platform - 'android' or 'ios'
      #
      # Throws a user_error if the binary file does not exist
      def upload_binary(app_name, binary_path, platform)
        response = connection.post(binary_upload_url(app_name), read_binary(binary_path)) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_OCTET_STREAM
          request.headers["X-Firebase-Client"] = "fastlane/#{Fastlane::FirebaseAppDistribution::VERSION}"
          request.headers["X-Goog-Upload-File-Name"] = File.basename(binary_path)
          request.headers["X-Goog-Upload-Protocol"] = "raw"
        end

        response.body[:name] || ''
      rescue Errno::ENOENT # Raised when binary_path file does not exist
        binary_type = binary_type_from_path(binary_path)
        UI.user_error!("#{ErrorMessage.binary_not_found(binary_type)}: #{binary_path}")
      end

      # Uploads the binary file if it has not already been uploaded
      # Takes at least POLLING_INTERVAL_SECONDS between polling get_upload_status
      #
      # args
      #   app_name - Firebase App resource name
      #   binary_path - Absolute path to your app's aab/apk/ipa file
      #
      # Returns the release_name of the uploaded release.
      #
      # Crashes if the number of polling retries exceeds MAX_POLLING_RETRIES or if the binary cannot
      # be uploaded.
      def upload(app_name, binary_path, platform)
        binary_type = binary_type_from_path(binary_path)

        UI.message("⌛ Uploading the #{binary_type}.")
        operation_name = upload_binary(app_name, binary_path, platform)

        upload_status_response = get_upload_status(operation_name)
        MAX_POLLING_RETRIES.times do
          if upload_status_response.success?
            UI.success("✅ Uploaded #{binary_type} successfully and created release #{upload_status_response.release_version}.")
            break
          elsif upload_status_response.release_updated?
            UI.success("✅ Uploaded #{binary_type} successfully; updated provisioning profile of existing release #{upload_status_response.release_version}.")
            break
          elsif upload_status_response.release_unmodified?
            UI.success("✅ The same #{binary_type} was found in release #{upload_status_response.release_version} with no changes, skipping.")
            break
          elsif upload_status_response.in_progress?
            sleep(POLLING_INTERVAL_SECONDS)
            upload_status_response = get_upload_status(operation_name)
          else
            if !upload_status_response.error_message.nil?
              UI.user_error!("#{ErrorMessage.upload_binary_error(binary_type)}: #{upload_status_response.error_message}")
            else
              UI.user_error!(ErrorMessage.upload_binary_error(binary_type))
            end
          end
        end
        unless upload_status_response.success?
          UI.crash!("It took longer than expected to process your #{binary_type}, please try again.")
        end

        upload_status_response.release_name
      end

      # Fetches the status of an uploaded binary
      #
      # args
      #   operation_name - Upload operation name (with binary hash)
      #
      # Returns the `done` status, as well as a release, error, or nil
      def get_upload_status(operation_name)
        response = connection.get(upload_status_url(operation_name)) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
        end
        return UploadStatusResponse.new(response.body)
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
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        end
        response.body[:testerUdids] || []
      end

      private

      def v1alpha_apps_url(app_id)
        "/v1alpha/apps/#{app_id}"
      end

      def v1_apps_url(app_name)
        "/v1/#{app_name}"
      end

      def aab_info_url(app_name)
        "#{v1_apps_url(app_name)}/aabInfo"
      end

      def update_release_notes_url(release_name)
        "/v1/#{release_name}"
      end

      def distribute_url(release_name)
        "/v1/#{release_name}:distribute"
      end

      def binary_upload_url(app_name)
        "/upload#{v1_apps_url(app_name)}/releases:upload"
      end

      def upload_status_url(operation_name)
        "/v1/#{operation_name}"
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
