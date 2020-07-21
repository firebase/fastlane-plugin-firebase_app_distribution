describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:fake_binary_path) { "binary_path" }
  let(:fake_binary_contents) { "Hello World" }
  let(:fake_binary) { double("Binary") }
  let(:fake_auth_client) { double("auth_client") }

  let(:api_client) { Fastlane::Client::FirebaseAppDistributionApiClient.new }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new(url: "https://firebaseappdistribution.googleapis.com") do |b|
      b.response(:json, parser_options: { symbolize_names: true })
      b.response(:raise_error)
      b.adapter(:test, stubs)
    end
  end

  before(:each) do
    allow(Signet::OAuth2::Client).to receive(:new)
      .and_return(fake_auth_client)
    allow(fake_auth_client).to receive(:fetch_access_token!)
    allow(fake_auth_client).to receive(:access_token)
      .and_return("fake_auth_token")

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
      upload_token = api_client.get_upload_token("app_id", fake_binary_path)
      binary_hash = Digest::SHA256.hexdigest(fake_binary_contents)
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
      expect { api_client.get_upload_token("app_id", fake_binary_path) }
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
      stubs.post("/app-binary-uploads?app_id=app_id", fake_binary_contents) do |env|
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
      stubs.post("/app-binary-uploads?app_id=invalid_app_id", fake_binary_contents) do |env|
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
    let(:upload_status_response_success) do
      UploadStatusResponse.new(
        { status: "SUCCESS",
          release: { id: "release_id" } }
      )
    end
    let(:upload_status_response_error) do
      UploadStatusResponse.new(
        { status: "ERROR",
          release: {} }
      )
    end

    before(:each) do
      # Stub out polling interval for quick specs
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::POLLING_INTERVAL_SECONDS", 0)

      # Expect a call to get_upload_token every time
      expect(api_client).to receive(:get_upload_token)
        .with("app_id", fake_binary_path)
        .and_return("upload_token").ordered
    end

    it 'skips the upload step if the binary has already been uploaded' do
      # upload should not attempt to upload the binary at all
      expect(api_client).not_to(receive(:upload_binary))
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_success)

      release_id = api_client.upload("app_id", fake_binary_path)
      expect(release_id).to eq("release_id")
    end

    it 'uploads the app binary then returns the release_id' do
      # return an error then a success after being uploaded
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_error, upload_status_response_success).ordered

      # upload_binary should only be called once
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path).ordered

      release_id = api_client.upload("app_id", fake_binary_path)
      expect(release_id).to eq("release_id")
    end

    it 'attempts to upload MAX_POLLING_RETRIES times' do
      max_polling_retries = 60
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::MAX_POLLING_RETRIES", max_polling_retries)

      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_error)
        .at_least(:once).ordered
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path)
        .exactly(max_polling_retries).times.ordered

      release_id = api_client.upload("app_id", fake_binary_path)
      expect(release_id).to be_nil
    end

    it 'uploads the app binary once then polls until success' do
      max_polling_retries = 60
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::MAX_POLLING_RETRIES", max_polling_retries)

      # return error the first time
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_error).ordered
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path).ordered
      # return in_progress for a couple polls
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(UploadStatusResponse.new({ status: "IN_PROGRESS", release: {} }))
        .exactly(max_polling_retries / 2).ordered
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_success).ordered

      release_id = api_client.upload("app_id", fake_binary_path)
      expect(release_id).to eq("release_id")
    end
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
      stubs.post("/v1alpha/apps/invalid_app_id/releases/release_id/notes", "{\"releaseNotes\":{\"releaseNotes\":\"release_notes\"}}") do |env|
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
      stubs.get("/v1alpha/apps/app_id/upload_status/app_token") do |env|
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
      stubs.get("/v1alpha/apps/invalid_app_id/upload_status/app_token") do |env|
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
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json) do |env|
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
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json) do |env|
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
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json) do |env|
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
