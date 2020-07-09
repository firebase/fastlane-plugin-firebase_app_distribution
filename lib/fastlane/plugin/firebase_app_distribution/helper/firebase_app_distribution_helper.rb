require 'fastlane_core/ui/ui'
require 'cfpropertylist'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    module FirebaseAppDistributionHelper
      def get_value_from_value_or_file(value, path)
        if (value.nil? || value.empty?) && !path.nil?
          begin
            return File.open(path).read
          rescue
            UI.crash!("#{ErrorMessage::INVALID_PATH}: #{path}")
          end
        end
        value
      end

      # Returns the array representation of a string with comma seperated values.
      def string_to_array(string)
        return nil if string.nil? || string.empty?
        string_array = string.gsub(/\s+/, '').split(",")
        return string_array
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
