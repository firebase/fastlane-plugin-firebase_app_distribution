require 'fastlane_core/ui/ui'
require 'cfpropertylist'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    module FirebaseAppDistributionHelper
      def get_value_from_value_or_file(value, path)
        if value.nil? || value.empty? && !path.nil? || !path.empty?
          if File.exist?(path)
            return File.open(path).read
          end
          UI.crash!("#{ErrorMessage::APK_NOT_FOUND}: #{path}")
        end
        value
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
