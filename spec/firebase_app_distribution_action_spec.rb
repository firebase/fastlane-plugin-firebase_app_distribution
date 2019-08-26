describe Fastlane::Actions::FirebaseAppDistributionAction do
  describe '#run' do
    it 'shells out to firebase' do
      expect(Fastlane::Actions).to receive(:sh_control_output).with("/tmp/fake-firebase-cli appdistribution:distribute /tmp/FakeApp.ipa --app abc:123", { print_command: false, print_command_output: true })
      params = {
        app: "abc:123",
        ipa_path: "/tmp/FakeApp.ipa",
        firebase_cli_path: "/tmp/fake-firebase-cli"

      }
      Fastlane::Actions::FirebaseAppDistributionAction.run(params)
    end
  end

  describe "fastfiles" do
    it "integrates with the firebase cli" do
      expect(subject.class).to receive(:is_firebasecmd_supported?).and_return(true)
      expect(File).to receive(:exist?).with("/tmp/fake-firebase-cli").and_return(true)
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
