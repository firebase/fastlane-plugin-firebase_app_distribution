require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class FirebaseappdistroHelper
      # class methods that you define here become available in your action
      # as `Helper::FirebaseappdistroHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the firebaseappdistro plugin helper!")
      end

      # ensure that the firebase cli is installed and supports the expected flags
      def self.check_cli
        
      end
    end
  end
end
