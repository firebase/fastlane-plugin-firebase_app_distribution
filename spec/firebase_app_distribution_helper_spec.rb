describe Fastlane::Helper::FirebaseAppDistributionHelper do
  let(:helper) { Fastlane::Helper::FirebaseAppDistributionHelper }
  let(:fake_binary) { double("Binary") }

  before(:each) do
    allow(fake_binary).to receive(:read).and_return("Hello World")
  end

  describe '#get_value_from_value_or_file' do
    it 'should return the release notes string' do
      expect(helper.get_value_from_value_or_file("Hello World", "")).to eq("Hello World")
    end

    it 'should return the release notes from file' do
      expect(File).to receive(:open)
        .with("release_notes_path")
        .and_return(fake_binary)
      expect(helper.get_value_from_value_or_file("", "release_notes_path")).to eq("Hello World")
    end

    it 'should raise an error due to invalid release notes path ' do
      expect(File).to receive(:open)
        .with("invalid_release_notes_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { helper.get_value_from_value_or_file("", "invalid_release_notes_path") }
        .to raise_error("#{ErrorMessage::INVALID_PATH}: invalid_release_notes_path")
    end
  end
end
