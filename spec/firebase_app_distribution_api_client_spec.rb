describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:api_client) { Fastlane::Client::FirebaseAppDistributionApiClient }
  let(:fake_binary) { double("Binary") }
  let(:fake_auth_client) { double("auth_client") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
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

    allow(api_client).to receive(:connection).and_return(conn)
  end

  after(:each) do
    stubs.verify_stubbed_calls
    Faraday.default_connection = nil
  end

  describe '#get_upload_token' do
    it 'should make a GET call to the app endpoint and return the upload token' do
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
      upload_token = api_client.get_upload_token("app_id", "binary_path")
      binary_hash = Digest::SHA256.hexdigest("Hello World")
      expect(upload_token).to eq(CGI.escape("projects/project_number/apps/app_id/releases/-/binaries/#{binary_hash}"))
    end

    it 'should crash if the app has no contact email' do
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
      expect { api_client.get_upload_token("app_id", "binary_path") }
        .to raise_error(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
    end

    it 'should crash if given an invalid app_id' do
      stubs.get("/v1alpha/apps/invalid_app_id") do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { api_client.get_upload_token("invalid_app_id", "binary_path") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'should crash if given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { api_client.get_upload_token("app_id", "invalid_binary_path") }
        .to raise_error("#{ErrorMessage::APK_NOT_FOUND}: invalid_binary_path")
    end
  end

  describe '#upload_binary' do
    it 'should upload the binary successfully' do
      stubs.post("/app-binary-uploads?app_id=app_id", "Hello World") do |env|
        [
          202,
          {},
          {
            token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash"
          }
        ]
      end
      api_client.upload_binary("app_id", "binary_path")
    end

    it 'should crash if given an invalid app_id' do
      stubs.post("/app-binary-uploads?app_id=invalid_app_id", "Hello World") do |env|
        [
          404,
          {},
          {}
        ]
      end
      expect { api_client.upload_binary("invalid_app_id", "binary_path") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'should crash if given an invalid binary_path' do
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
    it 'should post the notes successfully' do
      stubs.post("/v1alpha/apps/app_id/releases/release_id/notes", "{\"releaseNotes\":{\"releaseNotes\":\"release_notes\"}}") do |env|
        [
          200,
          {},
          {}
        ]
      end
      api_client.post_notes("app_id", "release_id", "release_notes")
    end

    it 'should not post if release notes are empty' do
      expect(conn).not_to(receive(:post))
      api_client.post_notes("app_id", "release_id", "")
    end

    it 'should not post if release notes are nil' do
      expect(conn).not_to(receive(:post))
      api_client.post_notes("app_id", "release_id", nil)
    end

    it 'should crash if given an invalid app_id' do
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
    it 'should return the proper status' do
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

    it 'should crash if given an invalid app_id' do
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
end
