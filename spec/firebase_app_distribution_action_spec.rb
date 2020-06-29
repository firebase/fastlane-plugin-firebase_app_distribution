describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:fake_file) { StringIO.new }
  let(:fake_connection) { double("Connection") }
  let(:fake_binary) { double("Binary") }
  # These examples are copied directly from API responses. Maybe we should move them to another file?
  let(:fake_get_app_response_valid) do
    double("Response", status: 200, body: {
      projectNumber: "project_number", appId: "app_id", platform: "android", bundleId: "bundle_id", contactEmail: "Hello@world.com"
    })
  end
  let(:fake_get_app_response_no_email) do
    double("Response", status: 200, body: {
      projectNumber: "project_number", appId: "app_id", platform: "android", bundleId: "bundle_id", contactEmail: ""
    })
  end
  let(:fake_get_app_response_invalid_app_id) do
    double("Response", status: 400, body: {
      error: { code: 400, message: "Request contains an invalid argument.", status: "INVALID_ARGUMENT" }
    })
  end
  let(:fake_get_app_response_permission_denied) do
    double("Response", status: 403, body: {
      error: { code: 403, message: "The caller does not have permission", status: "PERMISSION_DENIED" }
    })
  end
  let(:fake_upload_binary_response_valid) do
    double("Response", status: 202, body: {
      token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash"
    })
  end
  let(:fake_upload_status_response_success) do
    double("Response", status: 200, body: {
      status: "SUCCESS", release: { distributedAt: "1970-01-01T00:00:00Z", id: "status_id", lastActivityAt: "1970-01-01T00:00:00Z", receivedAt: "1970-01-01T00:00:00Z", displayVersion: "1.0", buildVersion: "1" }
    })
  end
  let(:fake_upload_status_response_invalid_app_token) do
    double("Response", status: 200, body: {
      status: "ERROR", message: "Update your Gradle plugin to >=2.0.0 or your Firebase CLI to >=8.4.1 to use the faster, more reliable upload pipeline.", release: { distributedAt: "1970-01-01T00:00:00Z", lastActivityAt: "1970-01-01T00:00:00Z", receivedAt: "1970-01-01T00:00:00Z" }
    })
  end

  before(:each) do
    allow(Fastlane::Actions::FirebaseAppDistributionAction).to receive(:connection).and_return(fake_connection)
    allow(fake_binary).to receive(:read).and_return("Hello World")
    allow(File).to receive(:open).and_return(fake_binary)
  end

  describe '#get_upload_token' do
    context 'when testing with valid parameters' do
      it 'should make a GET call to the app endpoint and return the upload token' do
        expect(fake_connection).to receive(:get)
          .with("/v1alpha/apps/app_id")
          .and_return(fake_get_app_response_valid)
        upload_token = Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path")
        binary_hash = Digest::SHA256.hexdigest("Hello World")
        expect(upload_token).to eq(CGI.escape("projects/project_number/apps/app_id/releases/-/binaries/#{binary_hash}"))
      end
    end

    context 'when testing with invalid parameters' do
      it 'should crash if the app has no contact email' do
        expect(fake_connection).to receive(:get)
          .with("/v1alpha/apps/app_id")
          .and_return(fake_get_app_response_no_email)
        expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path") }
          .to raise_error(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
      end

      it 'should crash if given an invalid app_id' do
        expect(fake_connection).to receive(:get)
          .with("/v1alpha/apps/invalid_app_id")
          .and_raise(Faraday::ResourceNotFound.new("404"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("invalid_app_id", "binary_path") }
          .to raise_error(ErrorMessage::INVALID_APP_ID)
      end

      it 'should crash if given an invalid binary_path' do
        expect(File).to receive(:open)
          .with("invalid_binary_path")
          .and_raise(Errno::ENOENT.new("file not found"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "invalid_binary_path") }
          .to raise_error(ErrorMessage::APK_NOT_FOUND)
      end
    end
  end

  describe '#upload_binary' do
    context 'when testing with valid parameters' do
      it 'should upload the binary successfully' do
        expect(fake_connection).to receive(:post)
          .with("/app-binary-uploads?app_id=app_id", "Hello World")
          .and_return(fake_upload_binary_response_valid)
        Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "binary_path")
      end
    end

    context 'when testing with invalid parameters' do
      it 'should crash if given an invalid app_id' do
        expect(fake_connection).to receive(:post)
          .with("/app-binary-uploads?app_id=invalid_app_id", "Hello World")
          .and_raise(Faraday::ResourceNotFound.new("404"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("invalid_app_id", "binary_path") }
          .to raise_error(ErrorMessage::INVALID_APP_ID)
      end

      it 'should crash if given an invalid binary_path' do
        expect(File).to receive(:open)
          .with("invalid_binary_path")
          .and_raise(Errno::ENOENT.new("file not found"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "invalid_binary_path") }
          .to raise_error(ErrorMessage::APK_NOT_FOUND)
      end
    end
  end

  describe '#upload' do
    # Empty for now
  end

  describe '#upload_status' do
    context 'when testing with valid parameters' do
      it 'should return the proper status' do
        expected_path = "/v1alpha/apps/app_id/upload_status/app_token"
        expect(fake_connection).to receive(:get)
          .with(expected_path)
          .and_return(fake_upload_status_response_success)
        status = Fastlane::Actions::FirebaseAppDistributionAction.upload_status("app_id", "app_token")
        expect(status).to eq("SUCCESS")
      end
    end

    context 'when testing with invalid parameters' do
      it 'should crash if given an invalid app_id' do
        expected_path = "/v1alpha/apps/invalid_app_id/upload_status/app_token"
        expect(fake_connection).to receive(:get)
          .with(expected_path)
          .and_raise(Faraday::ResourceNotFound.new("404"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_status("invalid_app_id", "app_token") }
          .to raise_error(ErrorMessage::INVALID_APP_ID)
      end
    end
  end
end
