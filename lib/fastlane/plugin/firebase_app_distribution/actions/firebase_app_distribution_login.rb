require 'googleauth'
require 'googleauth/stores/file_token_store'
require "google/apis/people_v1"
require "fileutils"

module Fastlane
  module Actions
    class FirebaseAppDistributionLoginAction < Action
      OOB_URI = "urn:ietf:wg:oauth:2.0:oob"
      SCOPE = "https://www.googleapis.com/auth/cloud-platform"
      CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
      CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"

      def self.run(params)
        client_id = Google::Auth::ClientId.new(CLIENT_ID, CLIENT_SECRET)
        authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, nil)
        url = authorizer.get_authorization_url(base_url: OOB_URI)

        UI.message("Please open the following address in your browser:")
        UI.message(url)
        UI.message("")
        code = UI.input("Enter the resulting code here: ")
        credentials = authorizer.get_credentials_from_code(code: code, base_url: OOB_URI)

        UI.message("Refresh Token: #{credentials.refresh_token}")
        UI.message("")
        UI.message("Set the refresh token as a FIREBASE_TOKEN environment variable")
      rescue Signet::AuthorizationError
        UI.error("The code you entered was invalid. Ensure that you have copied the code correctly.")
      rescue => error
        UI.error(error.to_s)
        UI.crash!("An error has occured please login again.")
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
