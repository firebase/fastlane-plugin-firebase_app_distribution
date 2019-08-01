describe Fastlane::Actions::FirebaseappdistroAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The firebaseappdistro plugin is working!")

      Fastlane::Actions::FirebaseappdistroAction.run(nil)
    end
  end

  describe "fastfiles" do
    it "integrates with the firebase cli" do
      command = Fastlane::FastFile.new.parse <<-CODE
        lane :test do
          firebaseappdistro(
            app:  "1:1234567890:ios:0a1b2c3d4e5f67890"
          )
        end
      CODE

      expect(command).to eq(
        ["firebase"]
      )
    end
  end
end
