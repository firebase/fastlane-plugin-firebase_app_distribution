describe Fastlane::Helper::FirebaseAppDistributionHelper do
  let(:helper) { Fastlane::Helper::FirebaseAppDistributionHelper }
  let(:fake_binary) { double("Binary") }

  before(:each) do
    allow(fake_binary).to receive(:read).and_return("Hello World")
  end

  describe '#get_value_from_value_or_file' do
    it 'returns the value when defined and the file path is empty' do
      expect(helper.get_value_from_value_or_file("Hello World", "")).to eq("Hello World")
    end

    it 'returns the value when value is defined and the file path is nil' do
      expect(helper.get_value_from_value_or_file("Hello World", nil)).to eq("Hello World")
    end

    it 'returns the release notes when the file path is valid and value is not defined' do
      expect(File).to receive(:open)
        .with("file_path")
        .and_return(fake_binary)
      expect(helper.get_value_from_value_or_file("", "file_path")).to eq("Hello World")
    end

    it 'returns the release notes when the file ath is valid and value is nil ' do
      expect(File).to receive(:open)
        .with("file_path")
        .and_return(fake_binary)
      expect(helper.get_value_from_value_or_file(nil, "file_path")).to eq("Hello World")
    end

    it 'raises an error when an invalid path is given and value is not defined' do
      expect(File).to receive(:open)
        .with("invalid_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { helper.get_value_from_value_or_file("", "invalid_path") }
        .to raise_error("#{ErrorMessage::INVALID_PATH}: invalid_path")
    end

    it 'raises an error when an invalid path is given and value is nil' do
      expect(File).to receive(:open)
        .with("invalid_path")
        .and_raise(Errno::ENOENT.new("file not found"))
      expect { helper.get_value_from_value_or_file(nil, "invalid_path") }
        .to raise_error("#{ErrorMessage::INVALID_PATH}: invalid_path")
    end
  end

  describe '#string_to_array' do
    it 'returns an array when a string is passed in with no commas' do
      array = helper.string_to_array("string")
      expect(array).to eq(["string"])
    end

    it 'returns an array when the string passed in has multiple values seperated by commas' do
      array = helper.string_to_array("string1, string2, string3")
      expect(array).to eq(["string1", "string2", "string3"])
    end

    it 'returns nil if the string is undefined' do
      array = helper.string_to_array(nil)
      expect(array).to eq(nil)
    end

    it 'returns nil when the string is empty' do
      array = helper.string_to_array("")
      expect(array).to eq(nil)
    end
  end
end
