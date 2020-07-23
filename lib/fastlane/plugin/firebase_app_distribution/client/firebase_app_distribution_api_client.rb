require 'fastlane_core/ui/ui'
require_relative '../actions/firebase_app_distribution_login'

module Fastlane
  module Client
    class FirebaseAppDistributionApiClient
      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token"
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_SECONDS = 2

      def initialize(auth_token)
        @auth_token = auth_token
      end

      def enable_access(app_id, release_id, emails, group_ids)
        if emails.nil? && group_ids.nil?
          UI.message("No testers passed in. Skipping this step.")
          return
        end
        begin
        payload = { emails: emails, groupIds: group_ids }
        connection.post(enable_access_url(app_id, release_id), payload.to_json) do |request|
          request.headers["Authorization"] = "Bearer " + @auth_token
        end
      rescue
        UI.user_error!("#{ErrorMessage::INVALID_TESTERS} \nEmails: #{emails} \nGroups: #{group_ids}")
      end
        UI.success("App Distribution upload finished successfully")
      end

      # Posts notes for the specified app release. Skips this
      # step if no notes are passed in (release_notes is nil/empty).
      #
      # args
      #   app_id - Firebase App ID
      #   release_id - App release ID, returned by upload_status endpoint
      #   release_notes - String of notes for this release
      #
      # Throws a user_error if app_id or release_id are invalid
      def post_notes(app_id, release_id, release_notes)
        payload = { releaseNotes: { releaseNotes: release_notes } }
        if release_notes.nil? || release_notes.empty?
          UI.message("No release notes passed in. Skipping this step.")
          return
        end
        begin
          connection.post(release_notes_create_url(app_id, release_id), payload.to_json) do |request|
            request.headers["Authorization"] = "Bearer " + @auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        rescue Faraday::ClientError
          UI.user_error!("#{ErrorMessage::INVALID_RELEASE_ID}: #{release_id}")
        end
        UI.success("Release notes have been posted.")
      end

      def get_upload_token(app_id, binary_path)
        begin
          binary_hash = Digest::SHA256.hexdigest(File.open(binary_path).read)
        rescue Errno::ENOENT
          UI.crash!("#{ErrorMessage::APK_NOT_FOUND}: #{binary_path}")
        end

        begin
          response = connection.get(v1_apps_url(app_id)) do |request|
            request.headers["Authorization"] = "Bearer " + @auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.crash!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        end
        contact_email = response.body[:contactEmail]
        if contact_email.nil? || contact_email.strip.empty?
          UI.crash!(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
        end
        return upload_token_format(response.body[:appId], response.body[:projectNumber], binary_hash)
      end

      def upload_binary(app_id, binary_path)
        connection.post(binary_upload_url(app_id), File.open(binary_path).read) do |request|
          request.headers["Authorization"] = "Bearer " + @auth_token
        end
      rescue Faraday::ResourceNotFound
        UI.crash!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
      rescue Errno::ENOENT
        UI.crash!("#{ErrorMessage::APK_NOT_FOUND}: #{binary_path}")
      end

      # Uploads the binary file if it has not already been uploaded
      # Takes at least POLLING_INTERVAL_SECONDS between polling get_upload_status
      #
      # args
      #   app_id - Firebase App ID
      #   binary_path - Absolute path to your app's apk/ipa file
      #
      # Returns the release_id on a successful release, otherwise returns nil.
      #
      # Throws an error if the number of polling retries exceeds MAX_POLLING_RETRIES
      def upload(app_id, binary_path)
        upload_token = get_upload_token(app_id, binary_path)
        upload_status_response = get_upload_status(app_id, upload_token)
        if upload_status_response.success?
          UI.success("This APK/IPA has been uploaded before. Skipping upload step.")
        else
          UI.message("This APK has not been uploaded before.")
          MAX_POLLING_RETRIES.times do
            if upload_status_response.success?
              UI.success("Uploaded APK/IPA Successfully!")
              break
            elsif upload_status_response.in_progress?
              sleep(POLLING_INTERVAL_SECONDS)
            else
              UI.message("Uploading the APK/IPA.")
              upload_binary(app_id, binary_path)
            end
            upload_status_response = get_upload_status(app_id, upload_token)
          end
          unless upload_status_response.success?
            UI.error("It took longer than expected to process your APK/IPA, please try again.")
            return nil
          end
        end
        upload_status_response.release_id
      end

      # Gets the upload status for the app release.
      def get_upload_status(app_id, app_token)
        begin
          response = connection.get(upload_status_url(app_id, app_token)) do |request|
            request.headers["Authorization"] = "Bearer " + @auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.crash!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        end
        return UploadStatusResponse.new(response.body)
      end

      private

      def v1_apps_url(app_id)
        "/v1alpha/apps/#{app_id}"
      end

      def release_notes_create_url(app_id, release_id)
        "#{v1_apps_url(app_id)}/releases/#{release_id}/notes"
      end

      def enable_access_url(app_id, release_id)
        "#{v1_apps_url(app_id)}/releases/#{release_id}/enable_access"
      end

      def binary_upload_url(app_id)
        "/app-binary-uploads?app_id=#{app_id}"
      end

      def upload_status_url(app_id, app_token)
        "#{v1_apps_url(app_id)}/upload_status/#{app_token}"
      end

      def upload_token_format(app_id, project_number, binary_hash)
        CGI.escape("projects/#{project_number}/apps/#{app_id}/releases/-/binaries/#{binary_hash}")
      end

      def connection
        @connection ||= Faraday.new(url: BASE_URL) do |conn|
          conn.response(:json, parser_options: { symbolize_names: true })
          conn.response(:raise_error) # raise_error middleware will run before the json middleware
          conn.adapter(Faraday.default_adapter)
        end
      end
    end
  end
end
