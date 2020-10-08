module Fastlane
  module Client
    class ErrorResponse
      attr_accessor :code, :message, :status

      def initialize(response)
        unless response[:body].nil? || response[:body].empty?
          response_body = JSON.parse(response[:body], symbolize_names: true)
          @code = response_body[:error][:code]
          @message = response_body[:error][:message]
          @status = response_body[:error][:status]
        end
      end
    end
  end
end
