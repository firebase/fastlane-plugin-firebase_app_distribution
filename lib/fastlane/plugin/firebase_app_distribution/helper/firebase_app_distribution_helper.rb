require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    module FirebaseAppDistributionHelper
      ##
      # always return a file for a given content
      # TODO: explain this more.
      def file_for_contents(parameter_name, from: nil, contents: nil)
        if parameter_name.to_s.end_with?("_file")
          return parameter_name
        end

        if @tempfiles.nil?
          @tempfiles = []
        end

        contents ||= from[parameter_name]
        return nil if contents.nil?

        file = Tempfile.new(parameter_name.to_s)
        file.write(contents)
        file.close
        @tempfiles << file

        file.path
      end

      def cleanup_tempfiles
        @tempfiles.each(&:unlink)
      end
    end
  end
end
