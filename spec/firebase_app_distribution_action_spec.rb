describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:fake_file) { StringIO.new }
  let(:temp_connection) { double("Connection") }
  let(:fake_response) { double("Response", body: { status: 200 , projectNumber: 1, appId: 1, contactEmail: "HelloWorld"})}
  let(:fake_binary) {double("Binary")}
  #file = instance_double(File, read: 'stubbed read')
#allow(File).to receive(:open).and_call_original
#allow(File).to receive(:open).with('file.txt') { |&block| block.call(file) }

  before(:each) do
    allow(Faraday).to receive(:new).and_return(temp_connection)
    allow(temp_connection).to receive(:get).and_return(fake_response)
    allow(fake_binary).to receive(:read).and_return("Hello World")
    allow(File).to receive(:open).and_return(fake_binary)
    allow(Tempfile).to receive(:new).and_return(fake_file)
    allow(fake_file).to receive(:unlink)
    allow(fake_file).to receive(:path).and_return("/tmp/string")
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
  describe '#upload_status' do
    it 'checks that you get a response' do
      expected_path = "/v1alpha/apps/app_id/upload_status/token"
      expect(temp_connection).to receive(:get).with(expected_path)
      status = Fastlane::Actions::FirebaseAppDistributionAction.upload_status("token", "app_id")
      expect(status).to eq(200)
    end
  end 


  describe '#get_upload_token' do
    it 'checks the contact email' do 
      expect(temp_connection).to receive(:get).with("/v1alpha/apps/app_id")
      upload_token = Fastlane::Actions::FirebaseAppDistributionAction.get_upload_token("app_id","binary_path")
      binary_hash = Digest::SHA256.hexdigest(File.open(fake_binary).read)
      expect(upload_token).to eq(CGI.escape("projects/1/apps/1/releases/-/binaries/#{binary_hash}"))
  end

  end

  describe "flag helpers" do
    let(:action) { Fastlane::Actions::FirebaseAppDistributionAction }

    describe "flag_value_if_supplied" do
      it "returns flag and param value when it exists" do
        params = {
            firebase_cli_token: 'fake-token'
        }
        expect(action.flag_value_if_supplied('--token', :firebase_cli_token, params)).to eq("--token fake-token")
      end

      it "returns nil if param does not exist" do
        params = {}
        expect(action.flag_value_if_supplied('--token', :firebåse_cli_token, params)).to be_nil
      end
    end

    describe "flag_if_supplied" do
      it "returns flag and param value when it exists" do
        params = {
            debug: true
        }
        expect(action.flag_if_supplied('--debug', :debug, params)).to eq("--debug")
      end

      it "returns nil if param does not exist" do
        params = {}
        expect(action.flag_if_supplied('--debug', :debug, params)).to be_nil
      end
    end

    describe "testers" do
      it "wraps string parameters as temp files" do
        params = {
          testers: "someone@example.com"
        }
        expect(fake_file).to receive(:write).with("someone@example.com")
        expect(action.testers_flag(params)).to eq("--testers-file /tmp/string")
      end

      it "will use a path if supplied" do
        params = {
          testers_file: "/tmp/testers_file"
        }
        expect(action.testers_flag(params)).to eq("--testers-file /tmp/testers_file")
      end
    end

    describe "groups" do
      it "wraps string parameters as temp files" do
        params = {
          groups: "somepeople"
        }
        expect(fake_file).to receive(:write).with("somepeople")
        expect(action.groups_flag(params)).to eq("--groups-file /tmp/string")
      end

      it "will use a path if supplied" do
        params = {
          groups_file: "/tmp/groups_file"
        }
        expect(action.groups_flag(params)).to eq("--groups-file /tmp/groups_file")
      end
    end

    describe "release_notes" do
      it "wraps string parameters as temp files" do
        params = {
          release_notes: "cool version"
        }
        expect(fake_file).to receive(:write).with("cool version")
        expect(action.release_notes_flag(params)).to eq("--release-notes-file /tmp/string")
      end

      it "will use a path if supplied" do
        params = {
          release_notes_file: "/tmp/release_notes.txt"
        }
        expect(action.release_notes_flag(params)).to eq("--release-notes-file /tmp/release_notes.txt")
      end
    end
  end

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
end
