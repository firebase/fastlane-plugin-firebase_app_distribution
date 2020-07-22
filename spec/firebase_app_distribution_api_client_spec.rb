describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:fake_binary_path) { "binary_path" }
  let(:fake_binary_contents) { "Hello World" }
  let(:fake_binary) { double("Binary") }
  let(:headers) { { 'Authorization' => 'Bearer auth_token' } }

  let(:api_client) { Fastlane::Client::FirebaseAppDistributionApiClient.new("auth_token") }
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
    allow(File).to receive(:open)
      .with(fake_binary_path)
      .and_return(fake_binary)

    allow(fake_binary).to receive(:read)
      .and_return(fake_binary_contents)

    allow(api_client).to receive(:connection)
      .and_return(conn)
  end

  after(:each) do
    stubs.verify_stubbed_calls
    Faraday.default_connection = nil
  end

  describe '#get_upload_token' do
    it 'returns the upload token after a successfull GET call' do
      stubs.get("/v1alpha/apps/app_id", headers) do |env|
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
      upload_token = api_client.get_upload_token("app_id", fake_binary_path)
      binary_hash = Digest::SHA256.hexdigest(fake_binary_contents)
      expect(upload_token).to eq(CGI.escape("projects/project_number/apps/app_id/releases/-/binaries/#{binary_hash}"))
    end

    it 'crash if the app has no contact email' do
      stubs.get("/v1alpha/apps/app_id", headers) do |env|
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
      expect { api_client.get_upload_token("app_id", fake_binary_path) }
        .to raise_error(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
    end

    it 'crashes when given an invalid app_id' do
      stubs.get("/v1alpha/apps/invalid_app_id", headers) do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { api_client.get_upload_token("invalid_app_id", fake_binary_path) }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'crashes when given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { api_client.get_upload_token("app_id", "invalid_binary_path") }
        .to raise_error("#{ErrorMessage::APK_NOT_FOUND}: invalid_binary_path")
    end
  end

  describe '#upload_binary' do
    it 'uploads the binary successfully when the input is valid' do
      stubs.post("/app-binary-uploads?app_id=app_id", fake_binary_contents, headers) do |env|
        [
          202,
          {},
          {
            token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash"
          }
        ]
      end
      api_client.upload_binary("app_id", fake_binary_path)
    end

    it 'should crash if given an invalid app_id' do
      stubs.post("/app-binary-uploads?app_id=invalid_app_id", fake_binary_contents, headers) do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { api_client.upload_binary("invalid_app_id", fake_binary_path) }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'crashes when given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { api_client.upload_binary("app_id", "invalid_binary_path") }
        .to raise_error("#{ErrorMessage::APK_NOT_FOUND}: invalid_binary_path")
    end
  end

  describe '#upload' do
    # Empty for now
  end

  describe '#post_notes' do
    let(:release_notes)  { "{\"releaseNotes\":{\"releaseNotes\":\"release_notes\"}}" }

    it 'post call is successfull when input is valid' do
      stubs.post("/v1alpha/apps/app_id/releases/release_id/notes", release_notes, headers) do |env|
        [
          200,
          {},
          {}
        ]
      end
      api_client.post_notes("app_id", "release_id", "release_notes")
    end

    it 'does not post when the release notes are empty' do
      expect(conn).not_to(receive(:post))
      api_client.post_notes("app_id", "release_id", "")
    end

    it 'does not post when the release notes are nil' do
      expect(conn).not_to(receive(:post))
      api_client.post_notes("app_id", "release_id", nil)
    end

    it 'crashes when given an invalid app_id' do
      stubs.post("/v1alpha/apps/invalid_app_id/releases/release_id/notes", release_notes, headers) do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { api_client.post_notes("invalid_app_id", "release_id", "release_notes") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end
  end

  describe '#upload_status' do
    it 'returns the proper status when the get call is successfull' do
      stubs.get("/v1alpha/apps/app_id/upload_status/app_token", headers) do |env|
        [
          200,
          {},
          { status: "SUCCESS" }
        ]
      end
      status = api_client.get_upload_status("app_id", "app_token")
      expect(status.success?).to eq(true)
    end

    it 'crashes when given an invalid app_id' do
      stubs.get("/v1alpha/apps/invalid_app_id/upload_status/app_token", headers) do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { api_client.get_upload_status("invalid_app_id", "app_token") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end
  end

  describe '#enable_access' do
    it 'posts successfully when tester emails and groupIds are defined' do
      payload = { emails: ["testers"], groupIds: ["groups"] }
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json, headers) do |env|
        [
          202,
          {},
          {}
        ]
      end
      api_client.enable_access("app_id", "release_id", ["testers"], ["groups"])
    end

    it 'posts when groupIds are defined and tester emails is nil' do
      payload = { emails: nil, groupIds: ["groups"] }
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json, headers) do |env|
        [
          202,
          {},
          {}
        ]
      end
      api_client.enable_access("app_id", "release_id", nil, ["groups"])
    end

    it 'posts when tester emails are defined and groupIds is nil' do
      payload = { emails: ["testers"], groupIds: nil }
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json, headers) do |env|
        [
          202,
          {},
          {}
        ]
      end
      api_client.enable_access("app_id", "release_id", ["testers"], nil)
    end

    it 'does not post if testers and groups are nil' do
      expect(conn).not_to(receive(:post))
      api_client.enable_access("app_id", "release_id", nil, nil)
    end
  end
end
