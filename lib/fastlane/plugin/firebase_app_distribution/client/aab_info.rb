class AabInfo
  # AAB states
  class AabState
    UNSPECIFIED = 'AAB_STATE_UNSPECIFIED'
    PLAY_ACCOUNT_NOT_LINKED = 'PLAY_ACCOUNT_NOT_LINKED'
    NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT = 'NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT'
    APP_NOT_PUBLISHED = 'APP_NOT_PUBLISHED'
    PLAY_IAS_TERMS_NOT_ACCEPTED = 'PLAY_IAS_TERMS_NOT_ACCEPTED'
    INTEGRATED = 'INTEGRATED'
    UNAVAILABLE = 'AAB_STATE_UNAVAILABLE'
  end

  def initialize(response)
    @response = response || {}
  end

  def integration_state
    @response[:integrationState]
  end

  def test_certificate
    @response[:testCertificate] || {}
  end

  def md5_certificate_hash
    test_certificate[:hashMd5]
  end

  def sha1_certificate_hash
    test_certificate[:hashSha1]
  end

  def sha256_certificate_hash
    test_certificate[:hashSha256]
  end

  def certs_provided?
    (!md5_certificate_hash.nil? && !md5_certificate_hash.empty?) &&
      (!sha1_certificate_hash.nil? && !sha1_certificate_hash.empty?) &&
      (!sha256_certificate_hash.nil? && !sha256_certificate_hash.empty?)
  end
end
