describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:fake_file) { StringIO.new }
  let(:temp_connection) { double("Connection") }
  # These examples are copied directly from API responses. Maybe we should move them to another file?
  let(:fake_get_app_response_valid) { double("Response", status: 200, body: { projectNumber: "1", appId: "1", platform: "android", bundleId: "1", contactEmail: "Hello@world.com" }) }
  let(:fake_get_app_response_no_email) { double("Response", status: 200, body: { projectNumber: "1", appId: "1", platform: "android", bundleId: "1", contactEmail: "" }) }
  let(:fake_get_app_response_invalid_app_id) { double("Response", status: 400, body: { error: { code: 400, message: "Request contains an invalid argument.", status: "INVALID_ARGUMENT" } }) }
  let(:fake_get_app_response_permission_denied) { double("Response", status: 403, body: { error: { code: 403, message: "The caller does not have permission", status: "PERMISSION_DENIED" } }) }
  let(:fake_upload_binary_response_valid) { double("Response", status: 202, body: { token: "projects/project_id/apps/app_id/releases/-/binaries/binary_hash" }) }
  let(:fake_upload_status_response_success) { double("Response", status: 200, body: { status: "SUCCESS", release: { distributedAt: "1970-01-01T00:00:00Z", id: "status_id", lastActivityAt: "1970-01-01T00:00:00Z", receivedAt: "1970-01-01T00:00:00Z", displayVersion: "1.0", buildVersion: "1" } }) }
  let(:fake_upload_status_response_invalid_app_token) { double("Response", status: 200, body: { status: "ERROR", message: "Update your Gradle plugin to >=2.0.0 or your Firebase CLI to >=8.4.1 to use the faster, more reliable upload pipeline.", release: { distributedAt: "1970-01-01T00:00:00Z", lastActivityAt: "1970-01-01T00:00:00Z", receivedAt: "1970-01-01T00:00:00Z" } }) }
  let(:fake_binary) { double("Binary") }

  before(:each) do
    allow(Fastlane::Actions::FirebaseAppDistributionAction).to receive(:connection).and_return(temp_connection)
    allow(fake_binary).to receive(:read).and_return("Hello World")

    allow(File).to receive(:open).and_return(fake_binary)
    allow(Tempfile).to receive(:new).and_return(fake_file)
    allow(fake_file).to receive(:unlink)
    allow(fake_file).to receive(:path).and_return("/tmp/string")
  end

  context '#get_upload_token' do
    context 'when testing with valid parameters' do
      it 'should make a GET call to the app endpoint and return the upload token' do
        expect(temp_connection).to receive(:get).with("/v1alpha/apps/app_id").and_return(fake_get_app_response_valid)
        upload_token = Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path")
        binary_hash = Digest::SHA256.hexdigest(File.open(fake_binary).read)
        expect(upload_token).to eq(CGI.escape("projects/1/apps/1/releases/-/binaries/#{binary_hash}"))
      end
    end

    context 'when testing with invalid parameters' do
      it 'should crash if the app has no contact email' do
        expect(temp_connection).to receive(:get).with("/v1alpha/apps/app_id").and_return(fake_get_app_response_no_email)
        expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "binary_path") }.to raise_error(ErrorMessage::GET_APP_NO_CONTACT_EMAIL_ERROR)
      end

      it 'should crash if given an invalid app_id' do
        expect(temp_connection).to receive(:get).with("/v1alpha/apps/invalid_app_id").and_raise(Faraday::ResourceNotFound.new("404"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("invalid_app_id", "binary_path") }.to raise_error(ErrorMessage::INVALID_APP_ID)
      end

      it 'should crash if given an invalid binary_path' do
        expect(File).to receive(:open).with("invalid_binary_path").and_raise(Errno::ENOENT.new("file not found"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id", "invalid_binary_path") }.to raise_error(ErrorMessage::APK_NOT_FOUND)
      end
    end
  end

  context '#upload_binary' do
    context 'when testing with valid parameters' do
      it 'should upload the binary successfully' do
        expect(temp_connection).to receive(:post).with("/app-binary-uploads?app_id=app_id", "Hello World").and_return(fake_upload_binary_response_valid)
        Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "binary_path")
      end
    end

    context 'when testing with invalid parameters' do
      it 'should crash if given an invalid app_id' do
        expect(temp_connection).to receive(:post).with("/app-binary-uploads?app_id=invalid_app_id", File.open("binary_path").read).and_raise(Faraday::ResourceNotFound.new("404"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("invalid_app_id", "binary_path") }.to raise_error(ErrorMessage::INVALID_APP_ID)
      end

      it 'should crash if given an invalid binary_path' do
        expect(File).to receive(:open).with("invalid_binary_path").and_raise(Errno::ENOENT.new("file not found"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_binary("app_id", "invalid_binary_path") }.to raise_error(ErrorMessage::APK_NOT_FOUND)
      end
    end
  end

  context '#upload' do
    # Empty for now
  end

  context '#upload_status' do
    context 'when testing with valid parameters' do
      it 'should return the proper status' do
        expected_path = "/v1alpha/apps/app_id/upload_status/app_token"
        expect(temp_connection).to receive(:get).with(expected_path).and_return(fake_upload_status_response_success)
        status = Fastlane::Actions::FirebaseAppDistributionAction.upload_status("app_id", "app_token")
        expect(status).to eq("SUCCESS")
      end
    end

    context 'when testing with invalid parameters' do
      it 'should crash if given an invalid app_id' do
        expected_path = "/v1alpha/apps/invalid_app_id/upload_status/app_token"
        expect(temp_connection).to receive(:get).with(expected_path).and_raise(Faraday::ResourceNotFound.new("404"))
        expect { Fastlane::Actions::FirebaseAppDistributionAction.upload_status("invalid_app_id", "app_token") }.to raise_error(ErrorMessage::INVALID_APP_ID)
      end
    end
  end
end

# describe '#run' do
#   it 'shells out to firebase' do
#     expect(Fastlane::Actions).to receive(:sh_control_output).with("/tmp/fake-firebase-cli appdistribution:distribute /tmp/FakeApp.ipa --app abc:123 --testers-file /tmp/testers.txt --release-notes-file /tmp/release_notes.txt --token fake-token --debug", { print_command: false, print_command_output: true })
#     params = {
#       app: "abc:123",
#       ipa_path: "/tmp/FakeApp.ipa",
#       firebase_cli_path: "/tmp/fake-firebase-cli",
#       testers_file: "/tmp/testers.txt",
#       release_notes_file: "/tmp/release_notes.txt",
#       firebase_cli_token: "fake-token",
#       debug: true
#     }
#     Fastlane::Actions::FirebaseAppDistributionAction.run(params)
#   end
# end

# describe "flag helpers" do
#   let(:action) { Fastlane::Actions::FirebaseAppDistributionAction }

#   describe "flag_value_if_supplied" do
#     it "returns flag and param value when it exists" do
#       params = {
#           firebase_cli_token: 'fake-token'
#       }
#       expect(action.flag_value_if_supplied('--token', :firebase_cli_token, params)).to eq("--token fake-token")
#     end

#     it "returns nil if param does not exist" do
#       params = {}
#       expect(action.flag_value_if_supplied('--token', :firebåse_cli_token, params)).to be_nil
#     end
#   end

#   describe "flag_if_supplied" do
#     it "returns flag and param value when it exists" do
#       params = {
#           debug: true
#       }
#       expect(action.flag_if_supplied('--debug', :debug, params)).to eq("--debug")
#     end

#     it "returns nil if param does not exist" do
#       params = {}
#       expect(action.flag_if_supplied('--debug', :debug, params)).to be_nil
#     end
#   end

#   describe "testers" do
#     it "wraps string parameters as temp files" do
#       params = {
#         testers: "someone@example.com"
#       }
#       expect(fake_file).to receive(:write).with("someone@example.com")
#       expect(action.testers_flag(params)).to eq("--testers-file /tmp/string")
#     end

#     it "will use a path if supplied" do
#       params = {
#         testers_file: "/tmp/testers_file"
#       }
#       expect(action.testers_flag(params)).to eq("--testers-file /tmp/testers_file")
#     end
#   end

#   describe "groups" do
#     it "wraps string parameters as temp files" do
#       params = {
#         groups: "somepeople"
#       }
#       expect(fake_file).to receive(:write).with("somepeople")
#       expect(action.groups_flag(params)).to eq("--groups-file /tmp/string")
#     end

#     it "will use a path if supplied" do
#       params = {
#         groups_file: "/tmp/groups_file"
#       }
#       expect(action.groups_flag(params)).to eq("--groups-file /tmp/groups_file")
#     end
#   end

#   describe "release_notes" do
#     it "wraps string parameters as temp files" do
#       params = {
#         release_notes: "cool version"
#       }
#       expect(fake_file).to receive(:write).with("cool version")
#       expect(action.release_notes_flag(params)).to eq("--release-notes-file /tmp/string")
#     end

#     it "will use a path if supplied" do
#       params = {
#         release_notes_file: "/tmp/release_notes.txt"
#       }
#       expect(action.release_notes_flag(params)).to eq("--release-notes-file /tmp/release_notes.txt")
#     end
#   end
# end

# describe "fastfiles" do
#   it "integrates with the firebase cli" do
#     expect(subject.class).to receive(:is_firebasecmd_supported?).and_return(true)
#     expect(File).to receive(:exist?).with("/tmp/fake-firebase-cli").and_return(true)
#     expect(Fastlane::Actions::FirebaseAppDistributionAction).to receive(:cleanup_tempfiles)

#     command = Fastlane::FastFile.new.parse(<<-CODE)
#       lane :test do
#         firebase_app_distribution(
#           app:  "1:1234567890:ios:0a1b2c3d4e5f67890",
#           firebase_cli_path: "/tmp/fake-firebase-cli"
#         )
#       end
#     CODE

#     command.test
#   end
# end
# end
