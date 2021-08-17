describe Fastlane::Client::FirebaseAppDistributionApiClient do
  let(:project_number) { 1_234_567_890 }
  let(:app_id) { "1:1234567890:android:321abc456def7890" }
  let(:app_name) { "projects/#{project_number}/apps/#{app_id}" }
  let(:release_name) { "#{app_name}/releases/release_id" }
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

  describe '#get_aab_info' do
    it 'returns aab info with no certs' do
      response = {
        name: "#{app_name}/aabInfo",
        integrationState: "ACTIVE"
      }
      stubs.get("/v1/#{app_name}/aabInfo", headers) do |env|
        [
          200,
          {}, # response headers
          response
        ]
      end
      aab_info = api_client.get_aab_info(app_name)
      expect(aab_info.certs_provided?).to eq(false)
      expect(aab_info.integration_state).to eq("ACTIVE")
      expect(aab_info.md5_certificate_hash).to eq(nil)
      expect(aab_info.sha1_certificate_hash).to eq(nil)
      expect(aab_info.sha256_certificate_hash).to eq(nil)
    end

    it 'returns aab info with certs' do
      response = {
        name: "#{app_name}/aabInfo",
        integrationState: "ACTIVE",
        testCertificate: {
          hashMd5: "md5-cert-hash",
          hashSha1: "sha1-cert-hash",
          hashSha256: "sha256-cert-hash"
        }
      }
      stubs.get("/v1/#{app_name}/aabInfo", headers) do |env|
        [
          200,
          {}, # response headers
          response
        ]
      end
      aab_info = api_client.get_aab_info(app_name)
      expect(aab_info.certs_provided?).to eq(true)
      expect(aab_info.integration_state).to eq("ACTIVE")
      expect(aab_info.md5_certificate_hash).to eq("md5-cert-hash")
      expect(aab_info.sha1_certificate_hash).to eq("sha1-cert-hash")
      expect(aab_info.sha256_certificate_hash).to eq("sha256-cert-hash")
    end
  end

  describe '#upload_binary' do
    let(:upload_headers) do
      { 'Authorization' => 'Bearer auth_token',
      'X-Firebase-Client' => "fastlane/#{Fastlane::FirebaseAppDistribution::VERSION}",
      'X-Goog-Upload-File-Name' => File.basename(fake_binary_path),
      'X-Goog-Upload-Protocol' => 'raw' }
    end
    it 'uploads the binary successfuly when the input is valid' do
      stubs.post("/upload/v1/#{app_name}/releases:upload", fake_binary_contents, upload_headers) do |env|
        [
          202,
          {}, # response headers
          {
            name: "#{app_name}/releases/-/operations/binary_hash"
          }
        ]
      end
      api_client.upload_binary(app_name, fake_binary_path, "android")
    end

    it 'crashes when given an invalid binary_path' do
      expect(File).to receive(:open)
        .with("invalid_binary.apk", "rb")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { api_client.upload_binary(app_name, "invalid_binary.apk", "android") }
        .to raise_error("#{ErrorMessage.binary_not_found('APK')}: invalid_binary.apk")
    end
  end

  describe '#upload' do
    let(:upload_status_response_success) do
      UploadStatusResponse.new(
        {
          done: true,
          response: {
            result: "RELEASE_CREATED",
            release: { name: release_name }
          }
        }
      )
    end
    let(:upload_status_response_release_updated) do
      UploadStatusResponse.new(
        {
          done: true,
          response: {
            result: "RELEASE_UPDATED",
            release: { name: release_name }
          }
        }
      )
    end
    let(:upload_status_response_release_unmodified) do
      UploadStatusResponse.new(
        {
          done: true,
          response: {
            result: "RELEASE_UNMODIFIED",
            release: { name: release_name }
          }
        }
      )
    end
    let(:upload_status_response_in_progress) do
      UploadStatusResponse.new({ done: false })
    end
    let(:upload_status_response_error) do
      UploadStatusResponse.new(
        {
          done: true,
          error: {
            message: "There was an error."
          }
        }
      )
    end
    let(:upload_status_response_status_unspecified) do
      UploadStatusResponse.new(
        {
          done: true,
          response: {
            result: "UPLOAD_RELEASE_RESULT_UNSPECIFIED"
          }
        }
      )
    end
    let(:operation_name) do
      CGI.escape("#{app_name}/releases/-/operations/#{Digest::SHA256.hexdigest(fake_binary_contents)}")
    end

    before(:each) do
      # Stub out polling interval for quick specs
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::POLLING_INTERVAL_SECONDS", 0)
    end

    it 'uploads the app binary then returns the release name' do
      expect(api_client).to receive(:upload_binary)
        .with(app_name, fake_binary_path, "android")
        .and_return(operation_name)
        .at_most(:once)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_in_progress)
        .at_most(:once)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_success)
        .at_most(:once)

      result = api_client.upload(app_name, fake_binary_path, "android")
      expect(result).to eq(release_name)
    end

    it 'uploads the app binary for an existing unmodified binary' do
      expect(api_client).to receive(:upload_binary)
        .with(app_name, fake_binary_path, "android")
        .and_return(operation_name)
        .at_most(:once)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_in_progress)
        .at_most(:once)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_release_unmodified)
        .at_most(:once)

      result = api_client.upload(app_name, fake_binary_path, "android")
      expect(result).to eq(release_name)
    end

    it 'uploads the app binary for an existing updated binary' do
      expect(api_client).to receive(:upload_binary)
        .with(app_name, fake_binary_path, "android")
        .and_return(operation_name)
        .at_most(:once)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_in_progress)
        .at_most(:once)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_release_updated)
        .at_most(:once)

      result = api_client.upload(app_name, fake_binary_path, "android")
      expect(result).to eq(release_name)
    end

    it 'raises an error after polling MAX_POLLING_RETRIES times' do
      max_polling_retries = 2
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::MAX_POLLING_RETRIES", max_polling_retries)

      expect(api_client).to receive(:upload_binary)
        .with(app_name, fake_binary_path, "android")
        .and_return(operation_name)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_in_progress)
        .exactly(max_polling_retries + 1).times # adding 1 for initial call

      expect do
        api_client.upload(app_name, fake_binary_path, "android")
      end.to raise_error
    end

    it 'uploads the app binary once then polls until success' do
      max_polling_retries = 3
      stub_const("Fastlane::Client::FirebaseAppDistributionApiClient::MAX_POLLING_RETRIES", max_polling_retries)

      expect(api_client).to receive(:upload_binary)
        .with(app_name, fake_binary_path, "android")
        .and_return(operation_name)
        .at_most(:once)
      # return in_progress for a couple polls
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_in_progress)
        .exactly(2).times
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_success)

      result = api_client.upload(app_name, fake_binary_path, "android")
      expect(result).to eq(release_name)
    end

    it 'crashes after failing to upload with status error' do
      expect(api_client).to receive(:upload_binary)
        .with(app_name, fake_binary_path, "android")
        .and_return(operation_name)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_error)
        .at_most(:once)

      expect { api_client.upload(app_name, fake_binary_path, "android") }
        .to raise_error("#{ErrorMessage.upload_binary_error('APK')}: #{upload_status_response_error.error_message}")
    end

    it 'crashes after failing to upload with status unspecified' do
      expect(api_client).to receive(:upload_binary)
        .with(app_name, fake_binary_path, "android")
        .and_return(operation_name)
      expect(api_client).to receive(:get_upload_status)
        .with(operation_name)
        .and_return(upload_status_response_status_unspecified)
        .at_most(:once)

      expect { api_client.upload(app_name, fake_binary_path, "android") }
        .to raise_error(ErrorMessage.upload_binary_error("APK"))
    end
  end

  describe '#update_release_notes' do
    let(:payload) do
      {
        name: release_name,
        releaseNotes: {
          text: "release_notes"
        }
      }
    end

    it 'patch call is successful when input is valid' do
      stubs.patch("/v1/#{release_name}?updateMask=release_notes.text", payload.to_json, headers) do |env|
        [
          200,
          {}, # response headers
          {}  # response body
        ]
      end
      api_client.update_release_notes(release_name, "release_notes")
    end

    it 'skips posting when release_notes is empty' do
      expect(conn).to_not(receive(:post))
      api_client.update_release_notes(release_name, "")
    end

    it 'skips posting when release_notes is nil' do
      expect(conn).to_not(receive(:post))
      api_client.update_release_notes(release_name, nil)
    end

    it 'raises a user error when a client error is returned' do
      stubs.patch("/v1/#{release_name}", payload.to_json, headers) do |env|
        [
          400,
          {}, # response headers
          { error: { message: "client error response message" } }.to_json
        ]
      end
      expect { api_client.update_release_notes(release_name, "release_notes") }
        .to raise_error("#{ErrorMessage::INVALID_RELEASE_NOTES}: client error response message")
    end
  end

  describe '#upload_status' do
    it 'returns the proper status when the get call is successful' do
      stubs.get("/v1/#{app_name}/releases/-/operations/binary_hash", headers) do |env|
        [
          200,
          {}, # response headers
          { done: true, response: { release: { name: '#{release_name}' }, result: 'RELEASE_CREATED' } }
        ]
      end
      status = api_client.get_upload_status("#{app_name}/releases/-/operations/binary_hash")
      expect(status.success?).to eq(true)
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
          {}  # response body
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
          {}  # response body
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
          {}  # response body
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
          {}  # response body
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

    it 'raises a user eror when a client error is returned' do
      emails = ["invalid_tester_email"]
      group_ids = ["invalid_group_id"]
      payload = { testerEmails: emails, groupAliases: group_ids }
      stubs.post("/v1/#{release_name}:distribute", payload.to_json) do |env|
        [
          400,
          {}, # response headers
          {}  # response body
        ]
      end
      expect { api_client.distribute(release_name, emails, group_ids) }
        .to raise_error("#{ErrorMessage::INVALID_TESTERS} \nEmails: #{emails} \nGroups: #{group_ids}")
    end
  end

  describe '#add_testers' do
    let(:headers) { { 'Authorization' => 'Bearer auth_token', 'Content-Type' => 'application/json' } }

    it 'is successful' do
      emails = %w[1@foo.com 2@foo.com]
      stubs.post("/v1/projects/project_number/testers:batchAdd", { emails: emails }.to_json, headers) do |env|
        [
          200,
          {}, # response headers
          {}  # response body
        ]
      end

      result = api_client.add_testers("project_number", emails)

      expect(result.success?).to eq(true)
    end

    it 'fails and prints correct error message for a 400' do
      emails = %w[foo 2@foo.com]
      stubs.post("/v1/projects/project_number/testers:batchAdd", { emails: emails }.to_json, headers) do |env|
        [
          400,
          {}, # response headers
          {}  # response body
        ]
      end

      expect { api_client.add_testers("project_number", emails) }
        .to raise_error(ErrorMessage::INVALID_EMAIL_ADDRESS)
    end

    it 'fails and prints correct error message for a 404' do
      emails = %w[1@foo.com 2@foo.com]
      stubs.post("/v1/projects/bad_project_number/testers:batchAdd", { emails: emails }.to_json, headers) do |env|
        [
          404,
          {}, # response headers
          {}  # response body
        ]
      end
      expect { api_client.add_testers("bad_project_number", emails) }
        .to raise_error(ErrorMessage::INVALID_PROJECT)
    end

    it 'fails and prints correct error message for a 429' do
      emails = %w[1@foo.com 2@foo.com]
      stubs.post("/v1/projects/project_number/testers:batchAdd", { emails: emails }.to_json, headers) do |env|
        [
          429,
          {}, # response headers
          {}  # response body
        ]
      end
      expect { api_client.add_testers("project_number", emails) }
        .to raise_error(ErrorMessage::TESTER_LIMIT_VIOLATION)
    end
  end

  describe '#remove_testers' do
    let(:headers) { { 'Authorization' => 'Bearer auth_token', 'Content-Type' => 'application/json' } }

    it 'returns the number of deleted testers' do
      emails = %w[1@foo.com 2@foo.com]
      stubs.post("/v1/projects/project_number/testers:batchRemove", { emails: emails }.to_json, headers) do |env|
        [
          200,
          {}, # response headers
          { emails: [{ name: '1@foo.com' }] }
        ]
      end

      result = api_client.remove_testers("project_number", emails)

      expect(result).to eq(1)
    end

    it 'fails and prints correct error message for a 404' do
      emails = %w[1@foo.com 2@foo.com]
      stubs.post("/v1/projects/bad_project_number/testers:batchRemove", { emails: emails }.to_json, headers) do |env|
        [
          404,
          {}, # response headers
          {}  # response body
        ]
      end
      expect { api_client.remove_testers("bad_project_number", emails) }
        .to raise_error(ErrorMessage::INVALID_PROJECT)
    end
  end
end
