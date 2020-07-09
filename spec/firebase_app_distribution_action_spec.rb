describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:fake_file) { StringIO.new }
  let(:fake_binary) { double("Binary") }
  let(:fake_auth_client) { double("auth_client") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:action) { Fastlane::Actions::FirebaseAppDistributionAction }
  let(:conn) do
    Faraday.new(url: "https://firebaseappdistribution.googleapis.com") do |b|
      b.response(:json, parser_options: { symbolize_names: true })
      b.response(:raise_error)
      b.adapter(:test, stubs)
    end
  end

  before(:each) do
    allow(Signet::OAuth2::Client).to receive(:new).and_return(fake_auth_client)
    allow(fake_auth_client).to receive(:fetch_access_token!)
    allow(fake_auth_client).to receive(:access_token).and_return("fake_auth_token")

    allow(fake_binary).to receive(:read).and_return("Hello World")
    allow(File).to receive(:open).and_return(fake_binary)

    allow(action).to receive(:connection).and_return(conn)
  end

  after(:each) do
    stubs.verify_stubbed_calls
    Faraday.default_connection = nil
  end

  describe '#get_value_from_value_or_file' do
    it 'returns the value when defined and the file path is empty' do
      expect(action.get_value_from_value_or_file("Hello World", "")).to eq("Hello World")
    end

    it 'returns the value when value is defined and the file path is nil' do
      expect(action.get_value_from_value_or_file("Hello World", nil)).to eq("Hello World")
    end

    it 'returns the release notes when the file path is valid and value is not defined' do
      expect(File).to receive(:open)
        .with("file_path")
        .and_return(fake_binary)
      expect(action.get_value_from_value_or_file("", "file_path")).to eq("Hello World")
    end

    it 'returns the release notes when the file ath is valid and value is nil ' do
      expect(File).to receive(:open)
        .with("file_path")
        .and_return(fake_binary)
      expect(action.get_value_from_value_or_file(nil, "file_path")).to eq("Hello World")
    end

    it 'raises an error when an invalid path is given and value is not defined' do
      expect(File).to receive(:open)
        .with("invalid_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { action.get_value_from_value_or_file("", "invalid_path") }
        .to raise_error("#{ErrorMessage::INVALID_PATH}: invalid_path")
    end

    it 'raises an error when an invalid path is given and value is nil' do
      expect(File).to receive(:open)
        .with("invalid_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { action.get_value_from_value_or_file(nil, "invalid_path") }
        .to raise_error("#{ErrorMessage::INVALID_PATH}: invalid_path")
    end
  end

  describe '#string_to_array' do
    it 'returns an array when a string is passed in with no commas' do
      array = action.string_to_array("string")
      expect(array).to eq(["string"])
    end

    it 'returns an array when the string passed in has multiple values seperated by commas' do
      array = action.string_to_array("string1, string2, string3")
      expect(array).to eq(["string1", "string2", "string3"])
    end

    it 'returns nil if the string is undefined' do
      array = action.string_to_array(nil)
      expect(array).to eq(nil)
    end

    it 'returns nil when the string is empty' do
      array = action.string_to_array("")
      expect(array).to eq(nil)
    end
  end

  describe '#enable_access' do
    it 'posts successfully when tester emails and groupIds are defined' do
      payload = { emails: ["testers"], groupIds: ["groups"] }
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json) do |env|
        [
          202,
          {},
          {}
        ]
      end
      action.enable_access("app_id", "release_id", ["testers"], ["groups"])
    end

    it 'posts when groupIds are defined and tester emails is nil' do
      payload = { emails: nil, groupIds: ["groups"] }
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json) do |env|
        [
          202,
          {},
          {}
        ]
      end
      action.enable_access("app_id", "release_id", nil, ["groups"])
    end

    it 'posts when tester emails are defined and groupIds is nil' do
      payload = { emails: ["testers"], groupIds: nil }
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json) do |env|
        [
          202,
          {},
          {}
        ]
      end
      action.enable_access("app_id", "release_id", ["testers"], nil)
    end

    it 'does not post if testers and groups are nil' do
      expect(conn).not_to(receive(:post))
      action.enable_access("app_id", "release_id", nil, nil)
    end
  end

  describe '#get_upload_token' do
    it 'returns the upload token after a successfull GET call' do
      stubs.get("/v1alpha/apps/app_id") do |env|
        [
          200,
          {},
          {
            projectNumber: "project_number",
            appId: "app_id",
            contactEmail: "Hello@world.com"
          }
        ]
      end
      upload_token = action.get_upload_token("app_id", "binary_path")
      binary_hash = Digest::SHA256.hexdigest("Hello World")
      expect(upload_token).to eq(CGI.escape("projects/project_number/apps/app_id/releases/-/binaries/#{binary_hash}"))
    end

    it 'crash if the app has no contact email' do
      stubs.get("/v1alpha/apps/app_id") do |env|
        [
          200,
          {},
          {
            projectNumber: "project_number",
            appId: "app_id",
            contactEmail: ""
          }
        ]
      end
      expect { action.get_upload_token("app_id", "binary_path") }
        .to raise_error(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
    end

    it 'crashes when given an invalid app_id' do
      stubs.get("/v1alpha/apps/invalid_app_id") do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { action.get_upload_token("invalid_app_id", "binary_path") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'crashes when given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { action.get_upload_token("app_id", "invalid_binary_path") }
        .to raise_error("#{ErrorMessage::APK_NOT_FOUND}: invalid_binary_path")
    end
  end

  describe '#upload_binary' do
    it 'uploads the binary successfully when the input is valid' do
      stubs.post("/app-binary-uploads?app_id=app_id", "Hello World") do |env|
        [
          202,
          {},
          {
            token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash"
          }
        ]
      end
      action.upload_binary("app_id", "binary_path")
    end

    it 'crashes when given an invalid app_id' do
      stubs.post("/app-binary-uploads?app_id=invalid_app_id", "Hello World") do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { action.upload_binary("invalid_app_id", "binary_path") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'crashes when given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { action.upload_binary("app_id", "invalid_binary_path") }
        .to raise_error("#{ErrorMessage::APK_NOT_FOUND}: invalid_binary_path")
    end
  end

  describe '#upload' do
    # Empty for now
  end

  describe '#post_notes' do
    it 'post call is successfull when input is valid' do
      stubs.post("/v1alpha/apps/app_id/releases/release_id/notes", "{\"releaseNotes\":{\"releaseNotes\":\"release_notes\"}}") do |env|
        [
          200,
          {},
          {}
        ]
      end
      action.post_notes("app_id", "release_id", "release_notes")
    end

    it 'does not post when the release notes are empty' do
      expect(conn).not_to(receive(:post))
      action.post_notes("app_id", "release_id", "")
    end

    it 'does not post when the release notes are nil' do
      expect(conn).not_to(receive(:post))
      action.post_notes("app_id", "release_id", nil)
    end

    it 'crashes when given an invalid app_id' do
      stubs.post("/v1alpha/apps/invalid_app_id/releases/release_id/notes", "{\"releaseNotes\":{\"releaseNotes\":\"release_notes\"}}") do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { action.post_notes("invalid_app_id", "release_id", "release_notes") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end
  end

  describe '#upload_status' do
    it 'returns the proper status when the get call is successfull' do
      stubs.get("/v1alpha/apps/app_id/upload_status/app_token") do |env|
        [
          200,
          {},
          { status: "SUCCESS" }
        ]
      end
      status = action.get_upload_status("app_id", "app_token")
      expect(status.success?).to eq(true)
    end

    it 'crashes when given an invalid app_id' do
      stubs.get("/v1alpha/apps/invalid_app_id/upload_status/app_token") do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { action.get_upload_status("invalid_app_id", "app_token") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end
  end
end
