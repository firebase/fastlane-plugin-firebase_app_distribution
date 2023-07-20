describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:project_number) { 1_234_567_890 }
  let(:app_id) { "1:1234567890:android:321abc456def7890" }
  let(:app_name) { "projects/#{project_number}/apps/#{app_id}" }
  let(:release_name) { "#{app_name}/releases/release_id" }
  let(:fake_binary_path) { "binary.apk" }
  let(:fake_binary_contents) { "Hello World" }
  let(:fake_binary) { double("Binary") }
  let(:headers) { { 'Authorization' => 'Bearer auth_token' } }
  let(:upload_timeout) { 300 }

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

  describe '#get_udids' do
    let(:udids) do
      [
        { udid: 'device-udid-1', name: 'device-name-1', platform: 'ios' },
        { udid: 'device-udid-1', name: 'device-name-1', platform: 'ios' }
      ]
    end

    it 'returns the list of UDIDs when the get call is successful' do
      stubs.get("/v1alpha/apps/#{app_id}/testers:getTesterUdids", headers) do |env|
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
      stubs.get("/v1alpha/apps/#{app_id}/testers:getTesterUdids", headers) do |env|
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

  describe '#distribute' do
    it 'posts successfuly when tester emails and groupIds are defined' do
      payload = { testerEmails: ["testers"], groupAliases: ["groups"] }
      stubs.post("/v1/#{release_name}:distribute", payload.to_json, headers) do |env|
        [
          202,
          {}, # response headers
          {} # response body
        ]
      end
      api_client.distribute(release_name, ["testers"], ["groups"])
    end

    it 'posts when groupIds are defined and tester emails is nil' do
      payload = { testerEmails: nil, groupAliases: ["groups"] }
      stubs.post("/v1/#{release_name}:distribute", payload.to_json, headers) do |env|
        [
          202,
          {}, # response headers
          {} # response body
        ]
      end
      api_client.distribute(release_name, nil, ["groups"])
    end

    it 'posts when tester emails are defined and groupIds is nil' do
      payload = { testerEmails: ["testers"], groupAliases: nil }
      stubs.post("/v1/#{release_name}:distribute", payload.to_json, headers) do |env|
        [
          202,
          {}, # response headers
          {} # response body
        ]
      end
      api_client.distribute(release_name, ["testers"], nil)
    end

    it 'skips posting if testers and groups are nil' do
      expect(conn).to_not(receive(:post))
      api_client.distribute(release_name, nil, nil)
    end

    it 'skips posting if testers and groups are empty' do
      expect(conn).to_not(receive(:post))
      api_client.distribute(release_name, [], [])
    end

    it 'raises a user error when a client error is returned' do
      emails = ["invalid_tester_email"]
      group_ids = ["invalid_group_id"]
      payload = { testerEmails: emails, groupAliases: group_ids }
      stubs.post("/v1/#{release_name}:distribute", payload.to_json) do |env|
        [
          400,
          {}, # response headers
          {} # response body
        ]
      end
      expect { api_client.distribute(release_name, emails, group_ids) }
        .to raise_error("#{ErrorMessage::INVALID_TESTERS} \nEmails: #{emails} \nGroup Aliases: #{group_ids}")
    end
  end
end
