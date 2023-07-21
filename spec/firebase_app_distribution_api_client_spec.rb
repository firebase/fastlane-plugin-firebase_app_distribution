describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:project_number) { 1_234_567_890 }
  let(:app_id) { "1:1234567890:android:321abc456def7890" }
  let(:api_client) { Fastlane::Client::FirebaseAppDistributionApiClient.new("auth_token") }
  let(:headers) { { 'Authorization' => 'Bearer auth_token' } }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:conn) do
    Faraday.new(url: "https://firebaseappdistribution.googleapis.com") do |b|
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

  describe '#get_udids' do
    let(:udids) do
      [
        { udid: 'device-udid-1', name: 'device-name-1', platform: 'ios' },
        { udid: 'device-udid-1', name: 'device-name-1', platform: 'ios' }
      ]
    end

    it 'returns the list of UDIDs when the get call is successful' do
      stubs.get("/v1alpha/apps/#{app_id}/testers:getTesterUdids", headers) do |_|
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
      stubs.get("/v1alpha/apps/#{app_id}/testers:getTesterUdids", headers) do |_|
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
