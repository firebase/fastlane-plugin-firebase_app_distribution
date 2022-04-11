require 'fastlane_core/ui/ui'
require 'cfpropertylist'
module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")
  module Helper
    module FirebaseAppDistributionHelper
      def binary_type_from_path(binary_path)
        extension = File.extname(binary_path)
        return :APK if extension == '.apk'
        return :AAB if extension == '.aab'
        return :IPA if extension == '.ipa'

        UI.user_error!("Unsupported distribution file format, should be .ipa, .apk or .aab")
      end

      def get_value_from_value_or_file(value, path)
        if (value.nil? || value.empty?) && !path.nil?
          begin
            return File.open(path).read
          rescue Errno::ENOENT
            UI.crash!("#{ErrorMessage::INVALID_PATH}: #{path}")
          end
        end
        value
      end

      # Returns the array representation of a string with trimmed comma
      # seperated values.
      def string_to_array(string)
        return nil if string.nil? || string.empty?
        # Strip string and then strip individual values
        string.strip.split(",").map(&:strip)
      end

      def parse_plist(path)
        CFPropertyList.native_types(CFPropertyList::List.new(file: path).value)
      end

      def get_ios_app_id_from_archive_plist(archive_path, plist_path)
        app_path = parse_plist("#{archive_path}/Info.plist")["ApplicationProperties"]["ApplicationPath"]
        UI.shell_error!("can't extract application path from Info.plist at #{archive_path}") if app_path.empty?
        identifier = parse_plist("#{archive_path}/Products/#{app_path}/#{plist_path}")["GOOGLE_APP_ID"]
        UI.shell_error!("can't extract GOOGLE_APP_ID") if identifier.empty?
        return identifier
      end

      def blank?(value)
        # Taken from https://apidock.com/rails/Object/blank%3F
        value.respond_to?(:empty?) ? value.empty? : !value
      end

      def present?(value)
        !blank?(value)
      end

      def app_name_from_app_id(app_id)
        "projects/#{app_id.split(':')[1]}/apps/#{app_id}"
      end
    end
  end
end
