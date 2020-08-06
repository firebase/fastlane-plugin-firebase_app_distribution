module ErrorMessage
  MISSING_CREDENTIALS = "Missing authentication credentials. Check that your Firebase refresh token is set or that your service account file path is correct and try again."
  MISSING_APP_ID = "Missing app id. Please check that it was passed in and try again"
  SERVICE_CREDENTIALS_NOT_FOUND = "Service credentials file does not exist. Please check the service credentials path and try again"
  PARSE_SERVICE_CREDENTIALS_ERROR = "Failed to extract service account information from the service credentials file"
  UPLOAD_RELEASE_NOTES_ERROR = "App Distribution halted because it had a problem uploading release notes"
  UPLOAD_TESTERS_ERROR = "App Distribution halted because it had a problem adding testers/groups"
  GET_RELEASE_TIMEOUT = "App Distribution failed to fetch release information"
  REFRESH_TOKEN_ERROR = "Could not generate credentials from the refresh token specified."
  GET_APP_ERROR = "App Distribution failed to fetch app information"
  APP_NOT_ONBOARDED_ERROR = "App Distribution not onboarded"
  GET_APP_NO_CONTACT_EMAIL_ERROR = "App Distribution could not find a contact email associated with this app. Contact Email"
  INVALID_APP_ID = "App Distribution could not find your app. Make sure to onboard your app by pressing the \"Get started\" button on the App Distribution page in the Firebase console: https://console.firebase.google.com/project/_/appdistribution. App ID"
  INVALID_PATH = "Could not read content from"
  INVALID_TESTERS = "Could not enable access for testers. Ensure that the groups exist and the tester emails are formatted correctly"
  INVALID_RELEASE_ID = "App distribution failed to fetch release with id"
  SERVICE_CREDENTIALS_ERROR = "Could not generate credentials from the service credentials file specified. Service Account Path"
  INVALID_CREDENTIALS = "App Distribution could not access this app. Check that your authentication credentials has valid permissions. App ID"

  def self.binary_not_found(binary_type)
    "Could not find the #{binary_type}. Make sure you set the #{binary_type} path parameter to point to your #{binary_type}"
  end

  def self.parse_binary_metadata_error(binary_type)
    "Failed to extract #{binary_type} metadata from the #{binary_type} path"
  end

  def self.upload_binary_error(binary_type)
    "App Distribution halted because it had a problem uploading the #{binary_type}"
  end

  def self.binary_processing_error(binary_type)
    "App Distribution failed to process the #{binary_type}"
  end
end
