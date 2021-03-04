class AabCertificate
  def initialize(response)
    @response = response || {}
  end

  def md5_certificate_hash
    @response[:certificateHashMd5]
  end

  def sha1_certificate_hash
    @response[:certificateHashSha1]
  end

  def sha256_certificate_hash
    @response[:certificateHashSha256]
  end

  def empty?
    (md5_certificate_hash.nil? || md5_certificate_hash.empty?) &&
      (sha1_certificate_hash.nil? || sha1_certificate_hash.empty?) &&
      (sha256_certificate_hash.nil? || sha256_certificate_hash.empty?)
  end
end
