require 'fastlane_core/ui/ui'
require_relative '../actions/firebase_app_distribution_login'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    module FirebaseAppDistributionHelper
      BASE_URL = "https://firebaseappdistribution.googleapis.com"
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token"

      def v1_apps_path(app_id)
        "/v1alpha/apps/#{app_id}"
      end

      def release_notes_create_path(app_id, release_id)
        "#{v1_apps_path(app_id)}/releases/#{release_id}/notes"
      end

      def binary_upload_path(app_id)
        "/app-binary-uploads?app_id=#{app_id}"
      end

      def upload_status_path(app_id, app_token)
        "#{v1_apps_path(app_id)}/upload_status/#{app_token}"
      end

      def upload_token_format(app_id, project_number, binary_hash)
        CGI.escape("projects/#{project_number}/apps/#{app_id}/releases/-/binaries/#{binary_hash}")
      end

      def connection
        @connection ||= Faraday.new(url: FirebaseAppDistributionHelper::BASE_URL) do |conn|
          conn.response(:json, parser_options: { symbolize_names: true })
          conn.response(:raise_error) # raise_error middleware will run before the json middleware
          conn.adapter(Faraday.default_adapter)
        end
      end

      def auth_token
        @auth_token ||= begin
          client = Signet::OAuth2::Client.new(
            token_credential_uri: TOKEN_CREDENTIAL_URI,
            client_id: Fastlane::Actions::FirebaseAppDistributionLoginAction::CLIENT_ID,
            client_secret: Fastlane::Actions::FirebaseAppDistributionLoginAction::CLIENT_SECRET,
            refresh_token: ENV["FIREBASE_TOKEN"]
          )
          client.fetch_access_token!
          return client.access_token
        rescue Signet::AuthorizationError
          UI.crash!(ErrorMessage::REFRESH_TOKEN_ERROR)
        end
      end


      def get_value_from_value_or_file(value, path)
        if (value.nil? || value.empty?) && (!path.nil? || !path.empty?)
          begin
            return File.open(path).read
          rescue
            UI.crash!("#{ErrorMessage::INVALID_PATH}: #{path}")
          end
        end
        value
      end

      def get_ios_app_id_from_archive(path)
        app_path = parse_plist("#{path}/Info.plist")["ApplicationProperties"]["ApplicationPath"]
        UI.shell_error!("can't extract application path from Info.plist at #{path}") if app_path.empty?
        identifier = parse_plist("#{path}/Products/#{app_path}/GoogleService-Info.plist")["GOOGLE_APP_ID"]
        UI.shell_error!("can't extract GOOGLE_APP_ID") if identifier.empty?
        return identifier
      end
    end
  end
end
