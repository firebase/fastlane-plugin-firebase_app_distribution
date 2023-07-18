require 'fastlane_core/ui/ui'
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
            request.headers[CLIENT_VERSION] = client_version_header_value
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
      #   timeout - The amount of seconds before the upload will timeout, if not completed
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

      # Uploads the binary file if it has not already been uploaded
      # Takes at least POLLING_INTERVAL_SECONDS between polling get_upload_status
      #
      # args
      #   app_name - Firebase App resource name
      #   binary_path - Absolute path to your app's aab/apk/ipa file
      #   timeout - The amount of seconds before the upload will timeout, if not completed
      #
      # Returns a `UploadStatusResponse` with the upload is complete.
      #
      # Crashes if the number of polling retries exceeds MAX_POLLING_RETRIES or if the binary cannot
      # be uploaded.
      def upload(app_name, binary_path, platform, timeout)
        binary_type = binary_type_from_path(binary_path)

        UI.message("⌛ Uploading the #{binary_type}.")
        operation_name = upload_binary(app_name, binary_path, platform, timeout)

        upload_status_response = get_upload_status(operation_name)
        MAX_POLLING_RETRIES.times do
          if upload_status_response.success?
            if upload_status_response.release_updated?
              UI.success("✅ Uploaded #{binary_type} successfully; updated provisioning profile of existing release #{upload_status_response.release_version}.")
              break
            elsif upload_status_response.release_unmodified?
              UI.success("✅ The same #{binary_type} was found in release #{upload_status_response.release_version} with no changes, skipping.")
              break
            else
              UI.success("✅ Uploaded #{binary_type} successfully and created release #{upload_status_response.release_version}.")
            end
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

        upload_status_response
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
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
        UploadStatusResponse.new(response.body)
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

      # Create testers
      #
      # args
      #   project_number - Firebase project number
      #   emails - An array of emails to be created as testers. A maximum of
      #            1000 testers can be created at a time.
      #
      def add_testers(project_number, emails)
        payload = { emails: emails }
        connection.post(add_testers_url(project_number), payload.to_json) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_JSON
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
      rescue Faraday::BadRequestError
        UI.user_error!(ErrorMessage::INVALID_EMAIL_ADDRESS)
      rescue Faraday::ResourceNotFound
        UI.user_error!(ErrorMessage::INVALID_PROJECT)
      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          UI.user_error!(ErrorMessage::TESTER_LIMIT_VIOLATION)
        else
          raise e
        end
      end

      # Delete testers
      #
      # args
      #   project_number - Firebase project number
      #   emails - An array of emails to be deleted as testers. A maximum of
      #            1000 testers can be deleted at a time.
      #
      # Returns the number of testers that were deleted
      def remove_testers(project_number, emails)
        payload = { emails: emails }
        response = connection.post(remove_testers_url(project_number), payload.to_json) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_JSON
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
        response.body[:emails] ? response.body[:emails].count : 0
      rescue Faraday::ResourceNotFound
        UI.user_error!(ErrorMessage::INVALID_PROJECT)
      end

      # Create tester group
      #
      # args
      #   project_number - Firebase project number
      #   group_alias - Alias of the tester group
      #   display_name - Display name of the tester group
      #
      def create_group(project_number, group_alias, display_name)
        payload = { name: "projects/#{project_number}/groups/#{group_alias}",
                    displayName: display_name }
        response = connection.post(add_tester_group_url(project_number), payload.to_json) do |request|
          request.params["groupId"] = group_alias
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_JSON
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
        response.body
      rescue Faraday::BadRequestError
        UI.user_error!(ErrorMessage::INVALID_TESTER_GROUP_NAME)
      rescue Faraday::ResourceNotFound
        UI.user_error!(ErrorMessage::INVALID_PROJECT)
      rescue Faraday::ConflictError
        UI.important("Tester group #{group_alias} already exists.")
        return {
          name: "projects/#{project_number}/groups/#{group_alias}"
        }
      rescue Faraday::ClientError => e
        raise e
      end

      # Add testers to group
      #
      # args
      #   project_number - Firebase project number
      #   group_alias - Alias of the tester group
      #   emails - An array of emails to be added to the group.
      #            A maximum of 1000 testers can be added at a time, if creating missing testers is enabled.
      #   create_missing_testers - If true, missing testers will be created and added to the group.
      #
      def add_testers_to_group(project_number, group_alias, emails, create_missing_testers = false)
        payload = { emails: emails,
                    createMissingTesters: create_missing_testers }
        response = connection.post(add_testers_to_group_url(project_number, group_alias), payload.to_json) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_JSON
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
        response.body
      rescue Faraday::BadRequestError
        UI.user_error!(ErrorMessage::INVALID_EMAIL_ADDRESS)
      rescue Faraday::ResourceNotFound
        UI.user_error!(ErrorMessage::INVALID_TESTER_GROUP)
      rescue Faraday::ClientError => e
        raise e
      end

      # Remove testers from group
      #
      # args
      #   project_number - Firebase project number
      #   group_alias - Alias of the tester group
      #   emails - An array of emails to be removed from the group.
      #
      def remove_testers_from_group(project_number, group_alias, emails)
        payload = { emails: emails }
        response = connection.post(remove_testers_from_group_url(project_number, group_alias), payload.to_json) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_JSON
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
        response.body
      rescue Faraday::BadRequestError
        UI.user_error!(ErrorMessage::INVALID_EMAIL_ADDRESS)
      rescue Faraday::ResourceNotFound
        UI.user_error!(ErrorMessage::INVALID_TESTER_GROUP)
      rescue Faraday::ClientError => e
        raise e
      end

      # Delete tester group
      #
      # args
      #   project_number - Firebase project number
      #   group_alias - Alias of the tester group
      #
      def delete_group(project_number, group_alias)
        response = connection.delete(delete_tester_group_url(project_number, group_alias)) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_JSON
          request.headers[CLIENT_VERSION] = client_version_header_value
        end
        response.body
      rescue Faraday::ResourceNotFound
        UI.user_error!(ErrorMessage::INVALID_TESTER_GROUP)
      end

      # List releases
      #
      # args
      #   app_name - Firebase App resource name
      #   page_size - The number of releases to return in the page
      #   page_token - A page token, received from a previous call
      #
      # Returns the response body. Throws a user_error if the app hasn't been onboarded to App Distribution.
      def list_releases(app_name, page_size = 100, page_token = nil)
        begin
          response = connection.get(list_releases_url(app_name), { pageSize: page_size.to_s, pageToken: page_token }) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
            request.headers[CLIENT_VERSION] = client_version_header_value
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_name}")
        end

        response.body
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

      def aab_info_url(app_name)
        "#{v1_apps_url(app_name)}/aabInfo"
      end

      def update_release_notes_url(release_name)
        "/v1/#{release_name}?updateMask=release_notes.text"
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

      def list_releases_url(app_name)
        "#{v1_apps_url(app_name)}/releases"
      end

      def get_udids_url(app_id)
        "#{v1alpha_apps_url(app_id)}/testers:getTesterUdids"
      end

      def add_testers_url(project_number)
        "/v1/projects/#{project_number}/testers:batchAdd"
      end

      def remove_testers_url(project_number)
        "/v1/projects/#{project_number}/testers:batchRemove"
      end

      def add_tester_group_url(project_number)
        "/v1/projects/#{project_number}/groups"
      end

      def delete_tester_group_url(project_number, group_alias)
        "/v1/projects/#{project_number}/groups/#{group_alias}"
      end

      def add_testers_to_group_url(project_number, group_alias)
        "/v1/projects/#{project_number}/groups/#{group_alias}:batchJoin"
      end

      def remove_testers_from_group_url(project_number, group_alias)
        "/v1/projects/#{project_number}/groups/#{group_alias}:batchLeave"
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
