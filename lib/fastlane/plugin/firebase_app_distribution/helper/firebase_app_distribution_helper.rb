require 'fastlane_core/ui/ui'
module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")
  module Helper
    module FirebaseAppDistributionHelper
      def self.get_value_from_value_or_file(value, path)
        if (value.nil? || value.empty?) && (!path.nil? || !path.empty?)
          begin
            return File.open(path).read
          rescue Errno::ENOENT
            UI.crash!("#{ErrorMessage::INVALID_PATH}: #{path}")
          end
        end
        value
      end

      def self.get_ios_app_id_from_archive(path)
        app_path = parse_plist("#{path}/Info.plist")["ApplicationProperties"]["ApplicationPath"]
        UI.shell_error!("can't extract application path from Info.plist at #{path}") if app_path.empty?
        identifier = parse_plist("#{path}/Products/#{app_path}/GoogleService-Info.plist")["GOOGLE_APP_ID"]
        UI.shell_error!("can't extract GOOGLE_APP_ID") if identifier.empty?
        return identifier
      end
    end
  end
end
