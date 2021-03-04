require_relative 'aab_certificate'

class App
  # AAB states
  class AabState
    UNSPECIFIED = "AAB_STATE_UNSPECIFIED"
    PLAY_ACCOUNT_NOT_LINKED = "PLAY_ACCOUNT_NOT_LINKED"
    NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT = "NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT"
    APP_NOT_PUBLISHED = "APP_NOT_PUBLISHED"
    PLAY_IAS_TERMS_NOT_ACCEPTED = "PLAY_IAS_TERMS_NOT_ACCEPTED"
    ACTIVE = "ACTIVE"
    UNAVAILABLE = "AAB_STATE_UNAVAILABLE"
  end

  attr_reader :aab_certificate

  def initialize(response)
    @response = response
    @aab_certificate = AabCertificate.new(response[:aabCertificate])
  end

  def app_id
    @response[:appId]
  end

  def project_number
    @response[:projectNumber]
  end

  def contact_email
    @response[:contactEmail]
  end

  def aab_state
    @response[:aabState]
  end
end
