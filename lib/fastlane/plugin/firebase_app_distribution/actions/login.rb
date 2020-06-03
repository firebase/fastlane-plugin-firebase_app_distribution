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
        # fastlane will take care of reading in the parameter and fetching the environment variable:

        client_id = Google::Auth::ClientId.new("563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com", "j9iVZfS8kkCEFUPaAeJV0sAi")
        scope = 'https://www.googleapis.com/auth/cloud-platform'
        token_store = nil
        authorizer = Google::Auth::UserAuthorizer.new(client_id, scope, token_store)
        url = authorizer.get_authorization_url(base_url: "urn:ietf:wg:oauth:2.0:oob")
        UI.message("Please open the following address in your browser:") # \n#{url}"
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
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: "FL_TEST_AUTH_API_TOKEN", # The name of the environment variable
                                       description: "API Token for TestAuthAction", # a short description of this parameter
                                       verify_block: proc do |value|
                                         UI.user_error!("No API token for TestAuthAction given, pass using `api_token: 'token'`") unless value && !value.empty?
                                         # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :development,
                                       env_name: "FL_TEST_AUTH_DEVELOPMENT",
                                       description: "Create a development certificate instead of a distribution one",
                                       is_string: false, # true: verifies the input is a string, false: every kind of value
                                       default_value: false) # the default value if the user didn't provide one
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          # ['TEST_AUTH_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["Your GitHub/Twitter Name"]
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #

        platform == :ios
      end
    end
  end
end
