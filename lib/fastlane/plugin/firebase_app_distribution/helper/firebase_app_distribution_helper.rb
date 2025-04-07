require 'fastlane/action'
require 'fastlane_core/ui/ui'
require 'cfpropertylist'
require 'google/apis/core'
require 'google/apis/options'
require_relative './firebase_app_distribution_error_message'

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
      def string_to_array(string, delimiter = /[,\n]/)
        return [] if string.nil?
        # Strip string and then strip individual values
        string.strip.split(delimiter).map(&:strip)
      end

      def app_id_from_params(params)
        plist_path = params[:googleservice_info_plist_path]
        if params[:app]
          UI.message("Using app ID from 'app' parameter")
          app_id = params[:app]
        elsif xcode_archive_path
          UI.message("Using app ID from the GoogleService-Info.plist file located using the 'googleservice_info_plist_path' parameter, relative to the archive path: #{xcode_archive_path}")
          app_id = get_ios_app_id_from_archive_plist(xcode_archive_path, plist_path)
        elsif plist_path
          UI.message("Using app ID from the GoogleService-Info.plist file located using the 'googleservice_info_plist_path' parameter directly since no archive path was found")
          app_id = get_ios_app_id_from_plist(plist_path)
        end
        if app_id.nil?
          UI.crash!(ErrorMessage::MISSING_APP_ID)
        end
        app_id
      end

      def lane_platform
        # to_sym shouldn't be necessary, but possibly fixes #376
        Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]&.to_sym
      end

      def xcode_archive_path
        # prevents issues on cross-platform build environments where an XCode build happens within
        # the same lane
        return nil if lane_platform == :android

        # rubocop:disable Require/MissingRequireStatement
        Actions.lane_context[Actions::SharedValues::XCODEBUILD_ARCHIVE]
        # rubocop:enable Require/MissingRequireStatement
      end

      def parse_plist(path)
        CFPropertyList.native_types(CFPropertyList::List.new(file: path).value)
      end

      def get_ios_app_id_from_archive_plist(archive_path, relative_plist_path)
        app_path = parse_plist("#{archive_path}/Info.plist")["ApplicationProperties"]["ApplicationPath"]
        UI.shell_error!("can't extract application path from Info.plist at #{archive_path}") if app_path.empty?
        return get_ios_app_id_from_plist("#{archive_path}/Products/#{app_path}/#{relative_plist_path}")
      end

      def get_ios_app_id_from_plist(plist_path)
        identifier = parse_plist(plist_path)["GOOGLE_APP_ID"]
        UI.shell_error!("can't extract GOOGLE_APP_ID from #{plist_path}") if identifier.empty?
        return identifier
      end

      def blank?(value)
        # Taken from https://apidock.com/rails/Object/blank%3F
        value.respond_to?(:empty?) ? value.empty? : !value
      end

      def present?(value)
        !blank?(value)
      end

      def project_number_from_app_id(app_id)
        app_id.split(':')[1]
      end

      def app_name_from_app_id(app_id)
        "#{project_name(project_number_from_app_id(app_id))}/apps/#{app_id}"
      end

      def project_name(project_number)
        "projects/#{project_number}"
      end

      def group_name(project_number, group_alias)
        "#{project_name(project_number)}/groups/#{group_alias}"
      end

      def init_google_api_client(debug, timeout = nil)
        if debug
          UI.important("Warning: Debug logging enabled. Output may include sensitive information.")
          Google::Apis.logger.level = Logger::DEBUG
        end

        Google::Apis::ClientOptions.default.application_name = "fastlane"
        Google::Apis::ClientOptions.default.application_version = Fastlane::FirebaseAppDistribution::VERSION
        unless timeout.nil?
          Google::Apis::ClientOptions.default.send_timeout_sec = timeout
        end
      end

      def deep_symbolize_keys(hash)
        result = {}
        hash.each do |key, value|
          result[key.to_sym] = value.kind_of?(Hash) ? deep_symbolize_keys(value) : value
        end
        result
      end
    end
  end
end
