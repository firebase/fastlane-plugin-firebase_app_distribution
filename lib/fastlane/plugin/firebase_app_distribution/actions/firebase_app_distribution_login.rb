require 'googleauth'
require 'googleauth/stores/file_token_store'
require "fileutils"

module Fastlane
  module Actions
    class FirebaseAppDistributionLoginAction < Action
      OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
      SCOPE = "https://www.googleapis.com/auth/cloud-platform"

      # In this type of application, the client secret is not treated as a secret.
      # See: https://developers.google.com/identity/protocols/OAuth2InstalledApp
      CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
      CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"

      def self.run(params)
        client_id = Google::Auth::ClientId.new(CLIENT_ID, CLIENT_SECRET)
        authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, nil)
        url = authorizer.get_authorization_url(base_url: OOB_URI)

        UI.message("Open the following address in your browser and sign in with your Google account:")
        UI.message(url)
        UI.message("")
        code = UI.input("Enter the resulting code here: ")
        credentials = authorizer.get_credentials_from_code(code: code, base_url: OOB_URI)
        UI.message("")

        UI.success("Set the refresh token as the FIREBASE_TOKEN environment variable")
        UI.success("Refresh Token: #{credentials.refresh_token}")
      rescue Signet::AuthorizationError
        UI.error("The code you entered is invalid. Copy and paste the code and try again.")
      rescue => error
        UI.error(error.to_s)
        UI.crash!("An error has occured, please login again.")
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
    end
  end
end
