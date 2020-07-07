class UploadStatusResponse
  def initialize(response_json_hash)
    @response_json_hash = response_json_hash
  end

  def status
    @response_json_hash[:status]
  end

  def success?
    status == 'SUCCESS'
  end

  def in_progress?
    status == "IN_PROGRESS"
  end

  def release_hash
    @response_json_hash[:release]
  end

  def release_id
    release_hash ? release_hash[:id] : nil
  end
end
