require 'fastlane_core/ui/ui'
module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")
  module Auth
    module FirebaseAppDistributionAuthClient
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token"

      def fetch_auth_token(google_service_path)
        config_path = find_firebase_tools
        if !google_service_path.nil? && !google_service_path.empty?
          service_account(google_service_path)
        elsif ENV["FIREBASE_TOKEN"]
          firebase_token(ENV["FIREBASE_TOKEN"])
        elsif ENV["GOOGLE_APPLICATION_CREDENTIALS"]
          service_account(ENV["GOOGLE_APPLICATION_CREDENTIALS"])
        elsif (refresh_token = has_refresh_token(config_path))
          firebase_token(refresh_token)
        else
          UI.crash!(ErrorMessage::MISSING_CREDENTIALS)
        end
      end

      private

      def has_refresh_token(config_path)
        if File.exist?(config_path)
          begin
           refresh_token = JSON.parse(File.read(config_path))['tokens']['refresh_token']
           unless refresh_token.nil? && refresh_token.empty?
             refresh_token
           end
         rescue NoMethodError
         end
        end
      end

      def find_firebase_tools
        if ENV["XDG_CONFIG_HOME"]
          File.expand_path("configstore/firebase-tools.json", ENV["XDG_CONFIG_HOME"])
        else
          File.expand_path(".config/configstore/firebase-tools.json", "~")
        end
      end

      def firebase_token(refresh_token)
        begin
          client = Signet::OAuth2::Client.new(
            token_credential_uri: TOKEN_CREDENTIAL_URI,
            client_id: Fastlane::Actions::FirebaseAppDistributionLoginAction::CLIENT_ID,
            client_secret: Fastlane::Actions::FirebaseAppDistributionLoginAction::CLIENT_SECRET,
            refresh_token: refresh_token
          )
        rescue Signet::AuthorizationError
          UI.crash!(ErrorMessage::REFRESH_TOKEN_ERROR)
        end
        client.fetch_access_token!
        client.access_token
      end

      def service_account(google_service_path)
        service_account_credentials = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(google_service_path),
          scope: Fastlane::Actions::FirebaseAppDistributionLoginAction::SCOPE
        )
        service_account_credentials.fetch_access_token!["access_token"]
      rescue Errno::ENOENT
        UI.crash!("#{ErrorMessage::SERVICE_CREDENTIALS_NOT_FOUND}: #{google_service_path}")
      end
    end
  end
end
