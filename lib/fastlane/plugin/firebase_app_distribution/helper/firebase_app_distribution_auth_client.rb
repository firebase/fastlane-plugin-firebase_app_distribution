require 'fastlane_core/ui/ui'
module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")
  module Auth
    module FirebaseAppDistributionAuthClient
      TOKEN_CREDENTIAL_URI = "https://oauth2.googleapis.com/token"
      REDACTION_EXPOSED_LENGTH = 5
      REDACTION_CHARACTER = "X"

      # Returns the auth token for any of the auth methods (Firebase CLI token,
      # Google service account, firebase-tools). To ensure that a specific
      # auth method is used, unset all other auth variables/parameters to nil/empty
      #
      # args
      #   google_service_path - Absolute path to the Google service account file
      #   firebase_cli_token - Firebase CLI refresh token from login action or
      #                        CI environment
      #   debug - Whether to enable debug-level logging
      #
      # env variables
      #   GOOGLE_APPLICATION_CREDENTIALS - see google_service_path
      #   FIREBASE_TOKEN - see firebase_cli_token
      #
      # Crashes if given invalid or missing credentials
      def fetch_auth_token(google_service_path, firebase_cli_token, debug = false)
        if !google_service_path.nil? && !google_service_path.empty?
          UI.message("Authenticating with --service_credentials_file path parameter: #{google_service_path}")
          token = service_account(google_service_path, debug)
        elsif !firebase_cli_token.nil? && !firebase_cli_token.empty?
          UI.message("Authenticating with --firebase_cli_token parameter")
          token = firebase_token(firebase_cli_token, debug)
        elsif !ENV["FIREBASE_TOKEN"].nil? && !ENV["FIREBASE_TOKEN"].empty?
          UI.message("Authenticating with FIREBASE_TOKEN environment variable")
          token = firebase_token(ENV["FIREBASE_TOKEN"], debug)
        elsif !ENV["GOOGLE_APPLICATION_CREDENTIALS"].nil? && !ENV["GOOGLE_APPLICATION_CREDENTIALS"].empty?
          UI.message("Authenticating with GOOGLE_APPLICATION_CREDENTIALS environment variable: #{ENV['GOOGLE_APPLICATION_CREDENTIALS']}")
          token = service_account(ENV["GOOGLE_APPLICATION_CREDENTIALS"], debug)
        elsif (refresh_token = refresh_token_from_firebase_tools)
          UI.message("No authentication method specified. Using cached Firebase CLI credentials.")
          token = firebase_token(refresh_token, debug)
        else
          UI.user_error!(ErrorMessage::MISSING_CREDENTIALS)
        end
        UI.success("🔐 Authenticated successfully.")
        token
      end

      private

      def refresh_token_from_firebase_tools
        if ENV["XDG_CONFIG_HOME"].nil? || ENV["XDG_CONFIG_HOME"].empty?
          config_path = File.expand_path(".config/configstore/firebase-tools.json", "~")
        else
          config_path = File.expand_path("configstore/firebase-tools.json", ENV["XDG_CONFIG_HOME"])
        end

        if File.exist?(config_path)
          begin
            refresh_token = JSON.parse(File.read(config_path))['tokens']['refresh_token']
            refresh_token unless refresh_token.nil? || refresh_token.empty?
          # TODO: Catch parser errors, improve error handling here
          # Returns nil when there is an empty "tokens" field in the firebase-tools json
          rescue NoMethodError
          end
        end
      end

      def firebase_token(refresh_token, debug)
        client = Signet::OAuth2::Client.new(
          token_credential_uri: TOKEN_CREDENTIAL_URI,
          client_id: Fastlane::Actions::FirebaseAppDistributionLoginAction::CLIENT_ID,
          client_secret: Fastlane::Actions::FirebaseAppDistributionLoginAction::CLIENT_SECRET,
          refresh_token: refresh_token
        )
        client.fetch_access_token!
        client.access_token
      rescue Signet::AuthorizationError => error
        error_message = ErrorMessage::REFRESH_TOKEN_ERROR
        if debug
          error_message += "\nRefresh token used: #{format_token(refresh_token)}\n"
          error_message += error_details(error)
        else
          error_message += " #{debug_instructions}"
        end
        UI.user_error!(error_message)
      end

      def service_account(google_service_path, debug)
        service_account_credentials = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(google_service_path),
          scope: Fastlane::Actions::FirebaseAppDistributionLoginAction::SCOPE
        )
        service_account_credentials.fetch_access_token!["access_token"]
      rescue Errno::ENOENT
        UI.user_error!("#{ErrorMessage::SERVICE_CREDENTIALS_NOT_FOUND}: #{google_service_path}")
      rescue Signet::AuthorizationError => error
        error_message = "#{ErrorMessage::SERVICE_CREDENTIALS_ERROR}: \"#{google_service_path}\""
        if debug
          error_message += "\n#{error_details(error)}"
        else
          error_message += ". #{debug_instructions}"
        end
        UI.user_error!(error_message)
      end

      def error_details(error)
        "#{error.message}\nResponse status: #{error.response.status}"
      end

      def debug_instructions
        "For more information, try again with firebase_app_distribution's \"debug\" parameter set to \"true\"."
      end

      # Formats and redacts a token for printing out during debug logging. Examples:
      #   'abcd' -> '"abcd"''
      #   'abcdef1234' -> '"XXXXXf1234" (redacted)'
      def format_token(str)
        redaction_notice = str.length > REDACTION_EXPOSED_LENGTH ? " (redacted)" : ""
        exposed_start_char = [str.length - REDACTION_EXPOSED_LENGTH, 0].max
        exposed_characters = str[exposed_start_char, REDACTION_EXPOSED_LENGTH]
        redacted_characters = REDACTION_CHARACTER * [str.length - REDACTION_EXPOSED_LENGTH, 0].max
        "\"#{redacted_characters}#{exposed_characters}\"#{redaction_notice}"
      end
    end
  end
end
