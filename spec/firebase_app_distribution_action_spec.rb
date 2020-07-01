describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:fake_file) { StringIO.new }
  let(:fake_connection) { double("Connection") }
  let(:fake_binary) { double("Binary") }

  before(:each) do
    allow(Fastlane::Actions::FirebaseAppDistributionAction).to receive(:connection).and_return(fake_connection)
    allow(fake_binary).to receive(:read).and_return("Hello World")
    allow(File).to receive(:open).and_return(fake_binary)
  end

  describe '#get_upload_token' do
    it 'should make a GET call to the app endpoint and return the upload token' do
      expect(fake_connection).to receive(:get)
        .with("/v1alpha/apps/app_id")
        .and_return(
          double("Response", status: 200, body: {
            projectNumber: "project_number",
            appId: "app_id",
            platform: "android",
            bundleId: "bundle_id",
            contactEmail: "Hello@world.com"
          })
        )
      upload_token = Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path")
      binary_hash = Digest::SHA256.hexdigest("Hello World")
      expect(upload_token).to eq(CGI.escape("projects/project_number/apps/app_id/releases/-/binaries/#{binary_hash}"))
    end

    it 'should crash if the app has no contact email' do
      expect(fake_connection).to receive(:get)
        .with("/v1alpha/apps/app_id")
        .and_return(
          double("Response", status: 200, body: {
            projectNumber: "project_number",
            appId: "app_id",
            platform: "android",
            bundleId: "bundle_id",
            contactEmail: ""
          })
        )
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path") }
        .to raise_error(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR + "\"\"")
    end

    it 'should crash if given an invalid app_id' do
      expect(fake_connection).to receive(:get)
        .with("/v1alpha/apps/invalid_app_id")
        .and_raise(Faraday::ResourceNotFound.new("404"))
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("invalid_app_id", "binary_path") }
        .to raise_error(ErrorMessage::INVALID_APP_ID + "invalid_app_id")
    end

    it 'should crash if given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "invalid_binary_path") }
        .to raise_error(ErrorMessage::APK_NOT_FOUND + "invalid_binary_path")
    end
  end

  describe '#upload_binary' do
    it 'should upload the binary successfully' do
      expect(fake_connection).to receive(:post)
        .with("/app-binary-uploads?app_id=app_id", "Hello World")
        .and_return(
          double("Response", status: 202, body: {
            token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash"
          })
        )
      Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "binary_path")
    end

    it 'should crash if given an invalid app_id' do
      expect(fake_connection).to receive(:post)
        .with("/app-binary-uploads?app_id=invalid_app_id", "Hello World")
        .and_raise(Faraday::ResourceNotFound.new("404"))
      expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("invalid_app_id", "binary_path") }
        .to raise_error(ErrorMessage::INVALID_APP_ID + "invalid_app_id")
    end

    it 'should crash if given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "invalid_binary_path") }
        .to raise_error(ErrorMessage::APK_NOT_FOUND + "invalid_binary_path")
    end
  end

  describe '#upload' do
    # Empty for now
  end

  describe '#post_notes' do
    it 'should post the notes successfully' do
      expected_path = "/v1alpha/apps/app_id/releases/release_id/notes"
      expect(fake_connection).to receive(:post)
        .with(expected_path, "{\"releaseNotes\":{\"releaseNotes\":\"release_notes\"}}")
      Fastlane::Actions::FirebaseAppDistributionAction.post_notes("app_id", "release_id", "release_notes")
    end
  end

  describe '#upload' do
    # Empty for now
  end

  describe '#upload_status' do
    it 'should return the proper status' do
      expected_path = "/v1alpha/apps/app_id/upload_status/app_token"
      expect(fake_connection).to receive(:get)
        .with(expected_path)
        .and_return(
          double("Response", status: 200, body: {
            status: "SUCCESS"
          })
        )
      status = Fastlane::Actions::FirebaseAppDistributionAction.get_upload_status("app_id", "app_token")
      expect(status.success?).to eq(true)
    end

    it 'should crash if given an invalid app_id' do
      expected_path = "/v1alpha/apps/invalid_app_id/upload_status/app_token"
      expect(fake_connection).to receive(:get)
        .with(expected_path)
        .and_raise(Faraday::ResourceNotFound.new("404"))
      expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_status("invalid_app_id", "app_token") }
        .to raise_error(ErrorMessage::INVALID_APP_ID + "invalid_app_id")
    end
  end
end
