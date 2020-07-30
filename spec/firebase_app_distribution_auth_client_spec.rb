describe Fastlane::Auth::FirebaseAppDistributionAuthClient do
  let(:auth_helper) { Class.new { extend(Fastlane::Auth::FirebaseAppDistributionAuthClient) } }
  let(:fake_binary) { double("Binary") }
  let(:fake_binary_contents) { double("Contents") }
  let(:fake_firebase_tools_contents) { "{\"tokens\": {\"refresh_token\": \"refresh_token\"} }" }
  let(:fake_firebase_tools_contents_no_tokens_field) { "{}" }
  let(:fake_firebase_tools_contents_no_refresh_field) { "{\"tokens\": \"empty\"}" }
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
    allow(File).to receive(:exist?).and_return(false)

    allow(ENV).to receive(:[])
      .with("GOOGLE_APPLICATION_CREDENTIALS")
      .and_return(nil)
    allow(ENV).to receive(:[])
      .with("FIREBASE_TOKEN")
      .and_return(nil)
    allow(ENV).to receive(:[])
      .with("XDG_CONFIG_HOME")
      .and_return(nil)
  end

  describe '#fetch_auth_token' do
    it 'uses service credentials for authorization when the path is passed in' do
      expect(auth_helper.fetch_auth_token("google_service_path")).to eq("service_fake_auth_token")
    end

    it 'uses service credentials for authorization when the environmental variable is set' do
      expect(ENV).to receive(:[])
        .with("GOOGLE_APPLICATION_CREDENTIALS")
        .and_return("google_service_path")
      expect(auth_helper.fetch_auth_token("")).to eq("service_fake_auth_token")
    end

    it 'uses service credentials for authorization when the environmental variable is set and path is nil' do
      expect(ENV).to receive(:[])
        .with("GOOGLE_APPLICATION_CREDENTIALS")
        .and_return("google_service_path")
      expect(auth_helper.fetch_auth_token(nil)).to eq("service_fake_auth_token")
    end

    it 'uses firebase token environmental variable if an empty google service path is passed in' do
      expect(ENV).to receive(:[]).with("FIREBASE_TOKEN").and_return("refresh_token").twice
      expect(auth_helper.fetch_auth_token("")).to eq("fake_auth_token")
    end

    it 'uses firebase token environmental variable if no google service path is passed in' do
      expect(ENV).to receive(:[]).with("FIREBASE_TOKEN").and_return("refresh_token").twice
      expect(auth_helper.fetch_auth_token(nil)).to eq("fake_auth_token")
    end

    it 'fails if no credentials are passed and the google service path is empty' do
      expect { auth_helper.fetch_auth_token("") }
        .to raise_error(ErrorMessage::MISSING_CREDENTIALS)
    end

    it 'fails if no credentials are passed and the google service path is nil' do
      expect { auth_helper.fetch_auth_token(nil) }
        .to raise_error(ErrorMessage::MISSING_CREDENTIALS)
    end

    it 'fails if the service credentials is not found' do
      expect(File).to receive(:open)
        .with("invalid_service_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { auth_helper.fetch_auth_token("invalid_service_path") }
        .to raise_error("#{ErrorMessage::SERVICE_CREDENTIALS_NOT_FOUND}: invalid_service_path")
    end

    it 'uses firebase tools json if there is not another auth method' do
      allow(File).to receive(:read)
        .and_return(fake_firebase_tools_contents)
      expect(File).to receive(:exist?).and_return(true)
      expect(auth_helper.fetch_auth_token(nil)).to eq("fake_auth_token")
    end

    it 'fails if the firebase tools has no tokens field' do
      allow(File).to receive(:read)
        .and_return(fake_firebase_tools_contents_no_tokens_field)
      expect(File).to receive(:exist?).and_return(true)
      expect { auth_helper.fetch_auth_token(nil) }
        .to raise_error(ErrorMessage::MISSING_REFRESH_TOKEN)
    end

    it 'fails if the firebase tools has no refresh_token field' do
      allow(File).to receive(:read)
        .and_return(fake_firebase_tools_contents_no_refresh_field)
      expect(File).to receive(:exist?).and_return(true)
      expect { auth_helper.fetch_auth_token(nil) }
        .to raise_error(ErrorMessage::MISSING_REFRESH_TOKEN)
    end
  end
end
