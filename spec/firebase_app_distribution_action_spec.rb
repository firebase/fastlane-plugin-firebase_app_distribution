describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:fake_file) { StringIO.new }

  before do
    allow(Tempfile).to receive(:new).and_return(fake_file)
    allow(fake_file).to receive(:unlink)
    allow(fake_file).to receive(:path).and_return("/tmp/string")
  end

  describe '#run' do
    it 'shells out to firebase' do
      expect(Fastlane::Actions).to receive(:sh_control_output).with("/tmp/fake-firebase-cli appdistribution:distribute /tmp/FakeApp.ipa --app abc:123 --testers-file /tmp/testers.txt --release-notes-file /tmp/release_notes.txt --token fake-token", { print_command: false, print_command_output: true })
      params = {
        app: "abc:123",
        ipa_path: "/tmp/FakeApp.ipa",
        firebase_cli_path: "/tmp/fake-firebase-cli",
        testers_file: "/tmp/testers.txt",
        release_notes_file: "/tmp/release_notes.txt",
        firebase_cli_token: "fake-token"
      }
      Fastlane::Actions::FirebaseAppDistributionAction.run(params)
    end

    it 'removes trailing newlines from firebase_cli_path' do
      expect(Fastlane::Actions).to receive(:sh_control_output).with("/tmp/fake-firebase-cli appdistribution:distribute /tmp/FakeApp.ipa --app abc:123 --testers-file /tmp/testers.txt --release-notes-file /tmp/release_notes.txt --token fake-token", { print_command: false, print_command_output: true })
      params = {
          app: "abc:123",
          ipa_path: "/tmp/FakeApp.ipa",
          firebase_cli_path: "/tmp/fake-firebase-cli\n",
          testers_file: "/tmp/testers.txt",
          release_notes_file: "/tmp/release_notes.txt",
          firebase_cli_token: "fake-token"
      }
      Fastlane::Actions::FirebaseAppDistributionAction.run(params)
    end
  end

  describe "flag helpers" do
    let(:action) { Fastlane::Actions::FirebaseAppDistributionAction }

    describe "flag_if_supplied" do
      it "returns flag and value when it exists" do
        params = {
            firebase_cli_token: 'fake-token'
        }
        expect(action.flag_if_supplied('--token', :firebase_cli_token, params)).to eq("--token fake-token")
      end

      it "returns nil if it does not exist" do
        params = {}
        expect(action.flag_if_supplied('--token', :firebåse_cli_token, params)).to be_nil
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

  describe "fastfiles" do
    it "integrates with the firebase cli" do
      expect(subject.class).to receive(:is_firebasecmd_supported?).and_return(true)
      expect(File).to receive(:exist?).with("/tmp/fake-firebase-cli").and_return(true)
      expect(Fastlane::Actions::FirebaseAppDistributionAction).to receive(:cleanup_tempfiles)

      command = Fastlane::FastFile.new.parse(<<-CODE)
        lane :test do
          firebase_app_distribution(
            app:  "1:1234567890:ios:0a1b2c3d4e5f67890",
            firebase_cli_path: "/tmp/fake-firebase-cli"
          )
        end
      CODE

      command.test
    end
  end
end
