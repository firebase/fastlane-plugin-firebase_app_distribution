module ErrorMessage
  def self.binary
    if Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::PLATFORM_NAME] == :ios
      @binary ||= "IPA"
    else
      @binary ||= "APK"
    end
  end

  MISSING_CREDENTIALS = "Missing credentials. Please check that a refresh token was set or service credentials were passed in and try again"
  BINARY_NOT_FOUND = "Could not find the #{binary}. Make sure you set the #{binary} path parameter to point to your #{binary}"
  MISSING_APP_ID = "Missing app id. Please check that it was passed in and try again"
  SERVICE_CREDENTIALS_NOT_FOUND = "Service credentials file does not exist. Please check the service credentials path and try again"
  PARSE_SERVICE_CREDENTIALS_ERROR = "Failed to extract service account information from the service credentials file"
  PARSE_BINARY_METADATA_ERROR = "Failed to extract #{binary} metadata from the #{binary} path"
  UPLOAD_RELEASE_NOTES_ERROR = "App Distribution halted because it had a problem uploading release notes"
  UPLOAD_TESTERS_ERROR = "App Distribution halted because it had a problem adding testers/groups"
  UPLOAD_BINARY_ERROR = "App Distribution halted because it had a problem uploading the #{binary}"
  BINARY_PROCESSING_ERROR = "App Distribution failed to process the #{binary}"
  GET_RELEASE_TIMEOUT = "App Distribution failed to fetch release information"
  REFRESH_TOKEN_ERROR = "Could not generate credentials from the refresh token specified"
  GET_APP_ERROR = "App Distribution failed to fetch app information"
  APP_NOT_ONBOARDED_ERROR = "App Distribution not onboarded"
  GET_APP_NO_CONTACT_EMAIL_ERROR = "App Distribution could not find a contact email associated with this app. Contact Email"
  INVALID_APP_ID = "App Distribution could not find your app. Make sure to onboard your app by pressing the \"Get started\" button on the App Distribution page in the Firebase console: https://console.firebase.google.com/project/_/appdistribution. App ID"
  INVALID_PATH = "Could not read content from"
  INVALID_TESTERS = "Could not enable access for testers. Ensure that the groups exist and the tester emails are formatted correctly"
  INVALID_RELEASE_ID = "App distribution failed to fetch release with id"
end
