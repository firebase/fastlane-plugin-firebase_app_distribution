require 'google/apis/firebaseappdistribution_v1'
require 'google/apis/firebaseappdistribution_v1alpha'

# This is partially copied from google/apis/firebaseappdistribution_v1alpha v0.9.0 (2024-12-08) based discovery document revision 20241204.
# We can't depend on that version directly as long as fastlane locks google-cloud-env < 2.0.0 (to support Ruby 2.6).
# Newer versions of the API clients depend on google-apis-core >= 0.15.0 which depends on googleauth ~> 1.9 which depends on google-cloud-env ~> 2.1.
# See also https://github.com/fastlane/fastlane/pull/21685#pullrequestreview-2490037163
module Google
  module Apis
    module FirebaseappdistributionV1alpha
      class GoogleFirebaseAppdistroV1alphaReleaseTest
        include Google::Apis::Core::Hashable

        attr_accessor :create_time
        attr_accessor :device_executions
        attr_accessor :display_name
        attr_accessor :login_credential
        attr_accessor :name
        attr_accessor :test_case
        attr_accessor :test_state

        def initialize(**args)
          update!(**args)
        end

        def update!(**args)
          @create_time = args[:create_time] if args.key?(:create_time)
          @device_executions = args[:device_executions] if args.key?(:device_executions)
          @display_name = args[:display_name] if args.key?(:display_name)
          @login_credential = args[:login_credential] if args.key?(:login_credential)
          @name = args[:name] if args.key?(:name)
          @test_case = args[:test_case] if args.key?(:test_case)
          @test_state = args[:test_state] if args.key?(:test_state)
        end

        class Representation < Google::Apis::Core::JsonRepresentation
          property :create_time, as: 'createTime'
          collection :device_executions, as: 'deviceExecutions', class: Google::Apis::FirebaseappdistributionV1alpha::GoogleFirebaseAppdistroV1alphaDeviceExecution, decorator: Google::Apis::FirebaseappdistributionV1alpha::GoogleFirebaseAppdistroV1alphaDeviceExecution::Representation
          property :display_name, as: 'displayName'
          property :login_credential, as: 'loginCredential', class: Google::Apis::FirebaseappdistributionV1alpha::GoogleFirebaseAppdistroV1alphaLoginCredential, decorator: Google::Apis::FirebaseappdistributionV1alpha::GoogleFirebaseAppdistroV1alphaLoginCredential::Representation
          property :name, as: 'name'
          property :test_case, as: 'testCase'
          property :test_state, as: 'testState'
        end
      end
    end
  end
end
