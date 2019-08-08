require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class FirebaseAppDistributionHelper
      # class methods that you define here become available in your action
      # as `Helper::FirebaseAppDistributionHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the firebase_app_distribution plugin helper!")
      end

      def self.file_for_contents()
        if @tempfiles == nil
          @tempfiles = []
        end

        
      end

      def self.cleanup_tempfiles
      end
    end
  end
end
