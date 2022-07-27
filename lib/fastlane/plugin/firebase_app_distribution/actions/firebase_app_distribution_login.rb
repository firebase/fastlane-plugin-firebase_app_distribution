require 'googleauth'
require "fileutils"

module Fastlane
  module Actions
    class FirebaseAppDistributionLoginAction < Action
      SCOPE = "https://www.googleapis.com/auth/cloud-platform"

      # In this type of application, the client secret is not treated as a secret.
      # See: https://developers.google.com/identity/protocols/OAuth2InstalledApp
      CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
      CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"

      def self.run(params)
        callback_uri = "http://localhost:#{params[:port]}"
        client_id = Google::Auth::ClientId.new(CLIENT_ID, CLIENT_SECRET)
        authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, nil, callback_uri)

        # Create an anti-forgery state token as described here:
        # https://developers.google.com/identity/protocols/OpenIDConnect#createxsrftoken
        state = SecureRandom.hex(16)
        url = authorizer.get_authorization_url(state: state)

        UI.message("Open the following address in your browser and sign in with your Google account:")
        UI.message(url)

        response_params = get_authorization_code(params[:port])

        # Confirm that the state in the response matches the state token used to
        # generate the authorization URL.
        unless state == response_params['state'][0]
          UI.crash!('An error has occurred. The state parameter in the authorization response does not match the expected state, which could mean that a malicious attacker is trying to make a login request.')
        end

        user_credentials = authorizer.get_credentials_from_code(
          code: response_params['code'][0]
        )
        UI.success("Set the refresh token as the FIREBASE_TOKEN environment variable")
        UI.success("Refresh Token: #{user_credentials.refresh_token}")
      rescue => error
        UI.error(error.to_s)
        UI.crash!("An error has occurred, please login again.")
      end

      def self.get_authorization_code(port)
        begin
          server = TCPServer.open(port)
        rescue Errno::EADDRINUSE => error
          UI.error(error.to_s)
          UI.crash!("Port #{port} is in use. Please specify a different one using the port parameter.")
        end
        client = server.accept
        callback_request = client.readline
        # Use a regular expression to extract the request line from the first line of
        # the callback request, e.g.:
        #   GET /?code=AUTH_CODE&state=XYZ&scope=... HTTP/1.1
        matcher = /GET +([^ ]+)/.match(callback_request)
        response_params = CGI.parse(URI.parse(matcher[1]).query) unless matcher.nil?

        client.puts("HTTP/1.1 200 OK")
        client.puts("Content-Type: text/html")
        client.puts("")
        client.puts("<b>")
        if response_params['code'].nil?
          client.puts("Failed to retrieve authorization code.")
        else
          client.puts("Authorization code was successfully retrieved.")
        end
        client.puts("</b>")
        client.puts("<p>Please check the console output.</p>")
        client.close

        return response_params
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Authenticate with Firebase App Distribution using a Google account."
      end

      def self.details
        "Log in to Firebase App Distribution using a Google account to generate an authentication "\
        "token. This token is stored within an environment variable and used to authenticate with your Firebase project. "\
        "See https://firebase.google.com/docs/app-distribution/ios/distribute-fastlane for more information."
      end

      def self.authors
        ["Manny Jimenez Github: mannyjimenez0810, Alonso Salas Infante Github: alonsosalasinfante"]
      end

      def self.is_supported?(platform)
        [:ios, :android].include?(platform)
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :port,
                                       env_name: "FIREBASEAPPDISTRO_LOGIN_PORT",
                                       description: "Port for the local web server which receives the response from Google's authorization server",
                                       default_value: "8081",
                                       optional: true,
                                       type: String)

        ]
      end

      def self.category
        :deprecated
      end

      def self.deprecated_notes
        "The firebase_app_distribution_login task is deprecated and will be removed in Q1 2023. See "\
        "https://firebase.google.com/docs/app-distribution/android/distribute-gradle#authenticate "\
        "for more information on alternative ways to authenticate."
      end
    end
  end
end
