class UploadStatusResponse
  def initialize(response_json_hash)
    @response_json_hash = response_json_hash
  end

  def done
    !!@response_json_hash[:done]
  end

  def response
    @response_json_hash[:response]
  end

  def release
    response ? response[:release] : nil
  end

  def release_name
    release ? release[:name] : nil
  end

  def release_version
    if release
      if release[:display_version] && release[:build_version]
        "#{release[:display_version]} (#{release[:build_version]})"
      elsif release[:display_version]
        release[:display_version]
      else
        release[:build_version]
      end
    end
  end

  def status
    response ? response[:result] : nil
  end

  def error
    @response_json_hash[:error]
  end

  def error_message
    error ? error[:message] : nil
  end

  def success?
    done && !!release
  end

  def in_progress?
    !done
  end

  def error?
    done && message
  end

  def release_updated?
    done && status == 'RELEASE_UPDATED'
  end

  def release_unmodified?
    done && status == 'RELEASE_UNMODIFIED'
  end
end
