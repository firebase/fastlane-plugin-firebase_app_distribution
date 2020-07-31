describe Fastlane::Auth::FirebaseAppDistributionAuthClient do
  let(:auth_helper) { Class.new { extend(Fastlane::Auth::FirebaseAppDistributionAuthClient) } }
  let(:fake_binary) { double("Binary") }
  let(:fake_binary_contents) { double("Contents") }
  let(:auth) { Google::Auth::ServiceAccountCredentials }
  let(:fake_service_creds) { double("service_account_creds") }
  let(:fake_auth_client) { double("auth_client") }
  let(:payload) { { "access_token" => "service_fake_auth_token" } }

  before(:each) do
    allow(Signet::OAuth2::Client).to receive(:new)
      .and_return(fake_auth_client)
    allow(fake_auth_client).to receive(:fetch_access_token!)
    allow(fake_auth_client).to receive(:access_token)
      .and_return("fake_auth_token")

    allow(auth).to receive(:make_creds)
      .with(anything)
      .and_return(fake_service_creds)
    allow(fake_service_creds).to receive(:fetch_access_token!)
      .and_return(payload)

    allow(File).to receive(:open)
      .and_return(fake_binary)
    allow(fake_binary).to receive(:read)
      .and_return(fake_binary_contents)
    allow(fake_binary_contents).to receive(:key)
      .and_return("fake_service_key")
  end

  describe '#fetch_auth_token' do
    describe 'with all other auth variables as nil' do
      before(:each) do
        allow(ENV).to receive(:[])
          .with("GOOGLE_APPLICATION_CREDENTIALS")
          .and_return(nil)
        allow(ENV).to receive(:[])
          .with("FIREBASE_TOKEN")
          .and_return(nil)
      end

      it 'auths with service credentials path' do
        expect(auth_helper.fetch_auth_token("google_service_path", nil))
          .to eq("service_fake_auth_token")
      end

      it 'auths with service credentials environment variable' do
        allow(ENV).to receive(:[])
          .with("GOOGLE_APPLICATION_CREDENTIALS")
          .and_return("google_service_path")
        expect(auth_helper.fetch_auth_token(nil, nil))
          .to eq("service_fake_auth_token")
      end

      it 'auths with firebase token environmental variable' do
        allow(ENV).to receive(:[])
          .with("FIREBASE_TOKEN")
          .and_return("refresh_token")
        expect(auth_helper.fetch_auth_token(nil, nil))
          .to eq("fake_auth_token")
      end

      it 'crashes if no credentials are given' do
        expect { auth_helper.fetch_auth_token(nil, nil) }
          .to raise_error(ErrorMessage::MISSING_CREDENTIALS)
      end

      it 'fails if the service credentials is not found' do
        expect(File).to receive(:open)
          .with("invalid_service_path")
          .and_raise(Errno::ENOENT.new("file not found"))
        expect { auth_helper.fetch_auth_token("invalid_service_path", nil) }
          .to raise_error("#{ErrorMessage::SERVICE_CREDENTIALS_NOT_FOUND}: invalid_service_path")
      end
    end

    describe 'with all other auth variables as empty' do
      before(:each) do
        allow(ENV).to receive(:[])
          .with("GOOGLE_APPLICATION_CREDENTIALS")
          .and_return("")
        allow(ENV).to receive(:[])
          .with("FIREBASE_TOKEN")
          .and_return("")
      end

      it 'auths with service credentials path' do
        expect(auth_helper.fetch_auth_token("google_service_path", ""))
          .to eq("service_fake_auth_token")
      end

      it 'auths with service credentials environment variable' do
        allow(ENV).to receive(:[])
          .with("GOOGLE_APPLICATION_CREDENTIALS")
          .and_return("google_service_path")
        expect(auth_helper.fetch_auth_token("", ""))
          .to eq("service_fake_auth_token")
      end

      it 'auths with firebase token environment variable' do
        allow(ENV).to receive(:[])
          .with("FIREBASE_TOKEN")
          .and_return("refresh_token")
        expect(auth_helper.fetch_auth_token("", ""))
          .to eq("fake_auth_token")
      end

      it 'crashes if no credentials are given' do
        expect { auth_helper.fetch_auth_token("", "") }
          .to raise_error(ErrorMessage::MISSING_CREDENTIALS)
      end
    end
  end
end
