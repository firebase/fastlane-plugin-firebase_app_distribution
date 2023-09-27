describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:project_number) { 1_234_567_890 }
  let(:app_id) { '1:1234567890:android:321abc456def7890' }
  let(:app_name) { '1234567890/apps/1:1234567890:android:321abc456def7890' }
  let(:binary_path) { '/path/to/β.ipa' }
  let(:binary_file) { StringIO.new('binary_file') }
  let(:api_client) { Fastlane::Client::FirebaseAppDistributionApiClient.new('auth_token') }
  let(:upload_headers) { { 'Authorization' => 'Bearer auth_token', 'X-Goog-Upload-File-Name' => '%CE%B2.ipa' } }
  let(:udid_headers) { { 'Authorization' => 'Bearer auth_token' } }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new(url: 'https://firebaseappdistribution.googleapis.com') do |b|
      b.response(:json, parser_options: { symbolize_names: true })
      b.response(:raise_error)
      b.adapter(:test, stubs)
    end
  end

  before(:each) do
    allow(api_client).to receive(:connection)
      .and_return(conn)
  end

  after(:each) do
    stubs.verify_stubbed_calls
    Faraday.default_connection = nil
  end

  describe '#upload_binary' do
    let(:upload) do
      app_name
    end

    it 'returns the long-running operation name when the upload call is successful' do
      allow(File).to receive(:open).with(binary_path, 'rb').and_return(binary_file)
      stubs.post("/upload/v1/#{app_name}/releases:upload", 'binary_file', upload_headers) do |_|
        [
          200,
          {}, # response headers
          { name: 'lro-name' }
        ]
      end
      result = api_client.upload_binary(app_name, binary_path, 'ios', 0)
      expect(result).to eq('lro-name')
    end
  end

  describe '#get_udids' do
    let(:udids) do
      [
        { udid: 'device-udid-1', name: 'device-name-1', platform: 'ios' },
        { udid: 'device-udid-1', name: 'device-name-1', platform: 'ios' }
      ]
    end

    it 'returns the list of UDIDs when the get call is successful' do
      stubs.get("/v1alpha/apps/#{app_id}/testers:getTesterUdids", udid_headers) do |_|
        [
          200,
          {}, # response headers
          { testerUdids: udids }
        ]
      end
      result = api_client.get_udids(app_id)
      expect(result).to eq(udids)
    end

    it 'returns an empty list UDIDs when there are no udids' do
      stubs.get("/v1alpha/apps/#{app_id}/testers:getTesterUdids", udid_headers) do |_|
        [
          200,
          {}, # response headers
          {} # response body
        ]
      end
      result = api_client.get_udids(app_id)
      expect(result).to eq([])
    end
  end
end
