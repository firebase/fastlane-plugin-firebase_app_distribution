describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:fake_file) { StringIO.new }
  let(:fake_connection) { double("Connection") }
  let(:fake_binary) { double("Binary") }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new(url: "https://firebaseappdistribution.googleapis.com") do |b|
      b.response(:json, parser_options: { symbolize_names: true })
      b.response(:raise_error)
      b.adapter(:test, stubs)
    end
  end

  before(:each) do
    allow(Fastlane::Actions::FirebaseAppDistributionAction).to receive(:connection).and_return(conn)
    allow(fake_binary).to receive(:read).and_return("Hello World")
    allow(File).to receive(:open).and_return(fake_binary)
  end

  after(:each) do
    stubs.verify_stubbed_calls
    Faraday.default_connection = nil
  end

  describe '#get_upload_token' do
    it 'should make a GET call to the app endpoint and return the upload token' do
      stubs.get("/v1alpha/apps/app_id") do |env|
        expect(env.url.path).to eq("/v1alpha/apps/app_id")
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
      upload_token = Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path")
      binary_hash = Digest::SHA256.hexdigest("Hello World")
      expect(upload_token).to eq(CGI.escape("projects/project_number/apps/app_id/releases/-/binaries/#{binary_hash}"))
    end

    it 'should crash if the app has no contact email' do
      stubs.get("/v1alpha/apps/app_id") do |env|
        expect(env.url.path).to eq("/v1alpha/apps/app_id")
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
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path") }
        .to raise_error(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
    end

    it 'should crash if given an invalid app_id' do
      stubs.get("/v1alpha/apps/invalid_app_id") do |env|
        expect(env.url.path).to eq("/v1alpha/apps/invalid_app_id")
        [
          404,
          {},
          {}
        ]
      end
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("invalid_app_id", "binary_path") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'should crash if given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "invalid_binary_path") }
        .to raise_error("#{ErrorMessage::APK_NOT_FOUND}: invalid_binary_path")
    end
  end

  describe '#upload_binary' do
    it 'should upload the binary successfully' do
      stubs.post("/app-binary-uploads?app_id=app_id", "Hello World") do |env|
        expect(env.url.path).to eq("/app-binary-uploads")
        [
          202,
          {},
          {
            token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash"
          }
        ]
      end
      Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "binary_path")
    end

    it 'should crash if given an invalid app_id' do
      stubs.post("/app-binary-uploads?app_id=invalid_app_id", "Hello World") do |env|
        expect(env.url.path).to eq("/app-binary-uploads")
        [
          404,
          {},
          {}
        ]
      end
      expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("invalid_app_id", "binary_path") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end

    it 'should crash if given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "invalid_binary_path") }
        .to raise_error("#{ErrorMessage::APK_NOT_FOUND}: invalid_binary_path")
    end
  end

  describe '#upload' do
    # Empty for now
  end

  describe '#post_notes' do
    it 'should post the notes successfully' do
      stubs.post("/v1alpha/apps/app_id/releases/release_id/notes", "{\"releaseNotes\":{\"releaseNotes\":\"release_notes\"}}") do |env|
        expect(env.url.path).to eq("/v1alpha/apps/app_id/releases/release_id/notes")
        [
          200,
          {},
          {}
        ]
      end
      Fastlane::Actions::FirebaseAppDistributionAction.post_notes("app_id", "release_id", "release_notes")
    end

    it 'should not post if release notes are empty' do
      expect(fake_connection).not_to(receive(:post))
      Fastlane::Actions::FirebaseAppDistributionAction.post_notes("app_id", "release_id", "")
    end

    it 'should not post if release notes are nil' do
      expect(fake_connection).not_to(receive(:post))
      Fastlane::Actions::FirebaseAppDistributionAction.post_notes("app_id", "release_id", nil)
    end
  end

  describe '#upload' do
    # Empty for now
  end

  describe '#upload_status' do
    it 'should return the proper status' do
      stubs.get("/v1alpha/apps/app_id/upload_status/app_token") do |env|
        expect(env.url.path).to eq("/v1alpha/apps/app_id/upload_status/app_token")
        [
          200,
          {},
          { status: "SUCCESS" }
        ]
      end
      status = Fastlane::Actions::FirebaseAppDistributionAction.get_upload_status("app_id", "app_token")
      expect(status.success?).to eq(true)
    end

    it 'should crash if given an invalid app_id' do
      stubs.get("/v1alpha/apps/invalid_app_id/upload_status/app_token") do |env|
        expect(env.url.path).to eq("/v1alpha/apps/invalid_app_id/upload_status/app_token")
        [
          404,
          {},
          {}
        ]
      end
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_status("invalid_app_id", "app_token") }
        .to raise_error("#{ErrorMessage::INVALID_APP_ID}: invalid_app_id")
    end
  end
end
