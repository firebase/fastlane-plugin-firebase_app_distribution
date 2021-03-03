describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:fake_binary_path) { "binary.apk" }
  let(:fake_binary_contents) { "Hello World" }
  let(:fake_binary) { double("Binary") }
  let(:headers) { { 'Authorization' => 'Bearer auth_token' } }

  let(:api_client) { Fastlane::Client::FirebaseAppDistributionApiClient.new("auth_token") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new(url: "https://firebaseappdistribution.googleapis.com") do |b|
      b.response(:json, parser_options: { symbolize_names: true })
      b.response(:raise_error)
      b.adapter(:test, stubs)
    end
  end

  before(:each) do
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open)
      .with(fake_binary_path, "rb")
      .and_return(fake_binary)

    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?)
      .with(fake_binary_path)
      .and_return(true)

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

    it 'crashes if the app has no contact email' do
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
      allow(File).to receive(:exist?)
        .with("invalid_binary.apk")
        .and_return(false)
      expect { api_client.get_upload_token("app_id", "invalid_binary.apk") }
        .to raise_error("#{ErrorMessage.binary_not_found('APK')}: invalid_binary.apk")
    end
  end

  describe '#upload_binary' do
    let(:upload_headers) do
      { 'Authorization' => 'Bearer auth_token',
      'X-APP-DISTRO-API-CLIENT-ID' => 'fastlane',
      'X-APP-DISTRO-API-CLIENT-TYPE' =>  "android",
      'X-APP-DISTRO-API-CLIENT-VERSION' => Fastlane::FirebaseAppDistribution::VERSION,
      'X-GOOG-UPLOAD-FILE-NAME' => File.basename(fake_binary_path),
      'X-GOOG-UPLOAD-PROTOCOL' => 'raw' }
    end
    it 'uploads the binary successfully when the input is valid' do
      stubs.post("/app-binary-uploads?app_id=app_id", fake_binary_contents, upload_headers) do |env|
        [
          202,
          {},
          {
            token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash"
          }
        ]
      end
      api_client.upload_binary("app_id", fake_binary_path, "android")
    end

    it 'crashes when given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary.apk", "rb")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { api_client.upload_binary("app_id", "invalid_binary.apk", "android") }
        .to raise_error("#{ErrorMessage.binary_not_found('APK')}: invalid_binary.apk")
    end
  end

  describe '#upload' do
    let(:upload_status_response_success) do
      UploadStatusResponse.new(
        { status: "SUCCESS",
          release: { id: "release_id" } }
      )
    end
    let(:upload_status_response_in_progress) do
      UploadStatusResponse.new(
        { status: "IN_PROGRESS",
          release: {} }
      )
    end
    let(:upload_status_response_error) do
      UploadStatusResponse.new(
        { status: "ERROR",
          release: {},
          message: "There was an error." }
      )
    end
    let(:upload_status_response_status_unspecified) do
      UploadStatusResponse.new(
        { status: "STATUS_UNSPECIFIED",
          release: {} }
      )
    end

    before(:each) do
      # Stub out polling interval for quick specs
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::POLLING_INTERVAL_SECONDS", 0)

      # Expect a call to get_upload_token every time
      expect(api_client).to receive(:get_upload_token)
        .with("app_id", fake_binary_path)
        .and_return("upload_token")
    end

    it 'skips the upload step if the binary has already been uploaded' do
      # upload should not attempt to upload the binary at all
      expect(api_client).to_not(receive(:upload_binary))
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_success)

      release_id = api_client.upload("app_id", fake_binary_path, "android")
      expect(release_id).to eq("release_id")
    end

    it 'uploads the app binary then returns the release_id' do
      # return an error then a success after being uploaded
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_error, upload_status_response_success)

      # upload_binary should only be called once
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path, "android")
        .at_most(:once)

      release_id = api_client.upload("app_id", fake_binary_path, "android")
      expect(release_id).to eq("release_id")
    end

    it 'returns nil after polling MAX_POLLING_RETRIES times' do
      max_polling_retries = 2
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::MAX_POLLING_RETRIES", max_polling_retries)

      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_error)
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path, "android")
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_in_progress)
        .exactly(max_polling_retries).times

      release_id = api_client.upload("app_id", fake_binary_path, "android")
      expect(release_id).to be_nil
    end

    it 'uploads the app binary once then polls until success' do
      max_polling_retries = 3
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::MAX_POLLING_RETRIES", max_polling_retries)

      # return error the first time
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_error)
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path, "android")
        .at_most(:once)
      # return in_progress for a couple polls
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_in_progress)
        .exactly(2).times
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_success)

      release_id = api_client.upload("app_id", fake_binary_path, "android")
      expect(release_id).to eq("release_id")
    end

    it 'crashes after failing to upload with status error' do
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_error).twice
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path, "android")

      expect { api_client.upload("app_id", fake_binary_path, "android") }
        .to raise_error("#{ErrorMessage.upload_binary_error('APK')}: #{upload_status_response_error.message}")
    end

    it 'crashes after failing to upload with status unspecified' do
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_status_unspecified).twice
      expect(api_client).to receive(:upload_binary)
        .with("app_id", fake_binary_path, "android")

      expect { api_client.upload("app_id", fake_binary_path, "android") }
        .to raise_error(ErrorMessage.upload_binary_error("APK"))
    end

    it 'does not call upload when the intial check returns in progress' do
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_in_progress)
      expect(api_client).to_not(receive(:upload_binary))
      expect(api_client).to receive(:get_upload_status)
        .with("app_id", "upload_token")
        .and_return(upload_status_response_success)

      release_id = api_client.upload("app_id", fake_binary_path, "android")
      expect(release_id).to eq("release_id")
    end
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

    it 'skips posting when release_notes is empty' do
      expect(conn).to_not(receive(:post))
      api_client.post_notes("app_id", "release_id", "")
    end

    it 'skips posting when release_notes is nil' do
      expect(conn).to_not(receive(:post))
      api_client.post_notes("app_id", "release_id", nil)
    end

    it 'raises a user error when a client error is returned' do
      stubs.post("/v1alpha/apps/app_id/releases/release_id/notes", release_notes, headers) do |env|
        [
          400,
          {},
          { error: { message: "client error response message" } }.to_json
        ]
      end
      expect { api_client.post_notes("app_id", "release_id", "release_notes") }
        .to raise_error("#{ErrorMessage::INVALID_RELEASE_NOTES}: client error response message")
    end

    # BUG: 500 errors causes a ClientError locally but ServerError on CircleCI specs, causing this test to be flaky.
    # it 'crashes when given an invalid release_id' do
    #   stubs.post("/v1alpha/apps/invalid_app_id/releases/invalid_release_id/notes", release_notes, headers) do |env|
    #     [
    #       500,
    #       {},
    #       {}
    #     ]
    #   end
    #   expect { api_client.post_notes("invalid_app_id", "invalid_release_id", "release_notes") }
    #     .to raise_error("#{ErrorMessage::INVALID_RELEASE_ID}: invalid_release_id")
    # end
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

    it 'skips posting if testers and groups are nil' do
      expect(conn).to_not(receive(:post))
      api_client.enable_access("app_id", "release_id", nil, nil)
    end

    it 'skips posting if testers and groups are empty' do
      expect(conn).to_not(receive(:post))
      api_client.enable_access("app_id", "release_id", [], [])
    end

    it 'raises a user eror when a client error is returned' do
      emails = ["invalid_tester_email"]
      group_ids = ["invalid_group_id"]
      payload = { emails: emails, groupIds: group_ids }
      stubs.post("/v1alpha/apps/app_id/releases/release_id/enable_access", payload.to_json) do |env|
        [
          400,
          {},
          {}
        ]
      end
      expect { api_client.enable_access("app_id", "release_id", emails, group_ids) }
        .to raise_error("#{ErrorMessage::INVALID_TESTERS} \nEmails: #{emails} \nGroups: #{group_ids}")
    end
  end
end
