require 'googleauth'
require 'googleauth/stores/file_token_store'
require "google/apis/people_v1"
# require "googleauth"
# require "googleauth/stores/file_token_store"
require "fileutils"
module Fastlane
  module Actions
    module SharedValues
      TEST_AUTH_CUSTOM_VALUE = :TEST_AUTH_CUSTOM_VALUE
    end

    class LoginAction < Action
      def self.run(params)
        client_id = Google::Auth::ClientId.new("563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com", "j9iVZfS8kkCEFUPaAeJV0sAi")
        scope = 'https://www.googleapis.com/auth/cloud-platform'
        token_store = nil
        authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
        url = authorizer.get_authorization_url(base_url: "urn:ietf:wg:oauth:2.0:oob")

        UI.message("Please open the following address in your browser:")
        UI.message(url.to_s)
        UI.message(" ")
        code = UI.input("Enter the resulting code here: ")
        credentials = authorizer.get_credentials_from_code(code: code, base_url: "urn:ietf:wg:oauth:2.0:oob")
        token = credentials.refresh_token

        UI.message("Refresh Token: #{token}")
        UI.message(" ")
        UI.message("Set the refresh token as a FIREBASE_TOKEN enviorment variable")
      rescue
        UI.message("An error has occured please login again. Ensure that you have copied the code correctly")
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Allow the user to login by getting a refresh token from the web and then setting an environmental variable to that token "
      end

      def self.details
        "You can use this action to do not have to login multiple times."
      end

      def self.available_options

      end

      def self.output
      end

      def self.return_value
      end

      def self.authors
        ["Manny Jimenez Github: mannyjimenez0810, Alonso Salas Infante Github: alonsosalasinfante"]
      end

      def self.is_supported?(platform)
      end
    end
  end
end
