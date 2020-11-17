require 'fastlane_core/ui/ui'
require_relative '../actions/firebase_app_distribution_login'
require_relative '../client/error_response'

module Fastlane
  module Client
    class FirebaseAppDistributionApiClient
      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token"
      MAX_POLLING_RETRIES = 60
      POLLING_INTERVAL_SECONDS = 2

      AUTHORIZATION = "Authorization"
      CONTENT_TYPE = "Content-Type"
      APPLICATION_JSON = "application/json"
      APPLICATION_OCTET_STREAM = "application/octet-stream"

      def initialize(auth_token, platform, debug = false)
        @auth_token = auth_token
        @debug = debug

        if platform.nil?
          @binary_type = "IPA/APK"
        elsif platform == :ios
          @binary_type = "IPA"
        else
          @binary_type = "APK"
        end
      end

      # Enables tester access to the specified app release. Skips this
      # step if no testers are passed in (emails and group_ids are nil/empty).
      #
      # args
      #   app_id - Firebase App ID
      #   release_id - App release ID, returned by upload_status endpoint
      #   emails - String array of app testers' email addresses
      #   group_ids - String array of Firebase tester group IDs
      #
      # Throws a user_error if app_id, emails, or group_ids are invalid
      def enable_access(app_id, release_id, emails, group_ids)
        if (emails.nil? || emails.empty?) && (group_ids.nil? || group_ids.empty?)
          UI.success("✅ No testers passed in. Skipping this step.")
          return
        end
        payload = { emails: emails, groupIds: group_ids }
        begin
          connection.post(enable_access_url(app_id, release_id), payload.to_json) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
            request.headers[CONTENT_TYPE] = APPLICATION_JSON
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        rescue Faraday::ClientError
          UI.user_error!("#{ErrorMessage::INVALID_TESTERS} \nEmails: #{emails} \nGroups: #{group_ids}")
        end
        UI.success("✅ Added testers/groups.")
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
          UI.success("✅ No release notes passed in. Skipping this step.")
          return
        end
        begin
          connection.post(release_notes_create_url(app_id, release_id), payload.to_json) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
            request.headers[CONTENT_TYPE] = APPLICATION_JSON
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        rescue Faraday::ClientError => e
          error = ErrorResponse.new(e.response)
          UI.user_error!("#{ErrorMessage::INVALID_RELEASE_NOTES}: #{error.message}")
        end
        UI.success("✅ Posted release notes.")
      end

      # Returns the url encoded upload token used for get_upload_status calls:
      # projects/<project-number>/apps/<app-id>/releases/-/binaries/<binary-hash>
      #
      # args
      #   app_id - Firebase App ID
      #   binary_path - Absolute path to your app's apk/ipa file
      #
      # Throws a user_error if an invalid app id is passed in, the binary file does
      # not exist, or invalid auth credentials are used (e.g. wrong project permissions)
      def get_upload_token(app_id, binary_path)
        if binary_path.nil? || !File.exist?(binary_path)
          UI.crash!("#{ErrorMessage.binary_not_found(@binary_type)}: #{binary_path}")
        end
        binary_hash = Digest::SHA256.hexdigest(read_binary(binary_path))

        begin
          response = connection.get(v1_apps_url(app_id)) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        end
        contact_email = response.body[:contactEmail]
        if contact_email.nil? || contact_email.strip.empty?
          UI.user_error!(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
        end
        return upload_token_format(response.body[:appId], response.body[:projectNumber], binary_hash)
      end

      # Uploads the app binary to the Firebase API
      #
      # args
      #   app_id - Firebase App ID
      #   binary_path - Absolute path to your app's apk/ipa file
      #   platform - 'android' or 'ios'
      #
      # Throws a user_error if an invalid app id is passed in, or if the binary file does not exist
      def upload_binary(app_id, binary_path, platform)
        connection.post(binary_upload_url(app_id), read_binary(binary_path)) do |request|
          request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          request.headers[CONTENT_TYPE] = APPLICATION_OCTET_STREAM
          request.headers["X-APP-DISTRO-API-CLIENT-ID"] = "fastlane"
          request.headers["X-APP-DISTRO-API-CLIENT-TYPE"] =  platform
          request.headers["X-APP-DISTRO-API-CLIENT-VERSION"] = Fastlane::FirebaseAppDistribution::VERSION
        end
      rescue Faraday::ResourceNotFound
        UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
      rescue Errno::ENOENT # Raised when binary_path file does not exist
        UI.user_error!("#{ErrorMessage.binary_not_found(@binary_type)}: #{binary_path}")
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
      # Throws a UI error if the number of polling retries exceeds MAX_POLLING_RETRIES
      # Crashes if not able to upload the binary
      def upload(app_id, binary_path, platform)
        upload_token = get_upload_token(app_id, binary_path)
        upload_status_response = get_upload_status(app_id, upload_token)
        if upload_status_response.success? || upload_status_response.already_uploaded?
          UI.success("✅ This #{@binary_type} has been uploaded before. Skipping upload step.")
        else
          unless upload_status_response.in_progress?
            UI.message("⌛ Uploading the #{@binary_type}.")
            upload_binary(app_id, binary_path, platform)
          end
          MAX_POLLING_RETRIES.times do
            upload_status_response = get_upload_status(app_id, upload_token)
            if upload_status_response.success? || upload_status_response.already_uploaded?
              UI.success("✅ Uploaded the #{@binary_type}.")
              break
            elsif upload_status_response.in_progress?
              sleep(POLLING_INTERVAL_SECONDS)
            else
              if !upload_status_response.message.nil?
                UI.user_error!("#{ErrorMessage.upload_binary_error(@binary_type)}: #{upload_status_response.message}")
              else
                UI.user_error!(ErrorMessage.upload_binary_error(@binary_type))
              end
            end
          end
          unless upload_status_response.success?
            UI.error("It took longer than expected to process your #{@binary_type}, please try again.")
            return nil
          end
        end
        upload_status_response.release_id
      end

      # Fetches the status of an uploaded binary
      #
      # args
      #   app_id - Firebase App ID
      #   upload_token - URL encoded upload token
      #
      # Returns the release ID on a successful release, otherwise returns nil.
      #
      # Throws a user_error if an invalid app_id is passed in
      def get_upload_status(app_id, upload_token)
        begin
          response = connection.get(upload_status_url(app_id, upload_token)) do |request|
            request.headers[AUTHORIZATION] = "Bearer " + @auth_token
          end
        rescue Faraday::ResourceNotFound
          UI.user_error!("#{ErrorMessage::INVALID_APP_ID}: #{app_id}")
        end
        return UploadStatusResponse.new(response.body)
      end

      def self.configure_connection(conn) # :nodoc:
        conn.response(:json, parser_options: { symbolize_names: true })
        conn.response(:raise_error) # raise_error middleware will run before the json middleware
        # The Firebase API seems to use the POST verb where it should use PUT, and all of those
        # are idempotent. Retry them since they can randomly fail in the wild.
        conn.request(:retry, { max: 5,
                               retry_statuses: [500, 501, 502, 503],
                               methods: %i[delete get head options put post] })
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
          self.class.configure_connection(conn)
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
