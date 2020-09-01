describe Fastlane::Helper::FirebaseAppDistributionHelper do
  let(:helper) { Class.new { extend(Fastlane::Helper::FirebaseAppDistributionHelper) } }
  let(:fake_binary) { double("Binary") }
  let(:app_path) { { "ApplicationProperties" => { "ApplicationPath" => "app_path" } } }
  let(:identifier) { { "GOOGLE_APP_ID" => "identifier" } }
  let(:plist) { double("plist") }

  before(:each) do
    allow(File).to receive(:open).and_call_original
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

    it 'returns the release notes when the file path is valid and value is nil ' do
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

  describe '#get_ios_app_id_from_archive' do
    it 'returns identifier ' do
      allow(CFPropertyList::List).to receive(:new)
        .with({ file: "path/Info.plist" })
        .and_return(plist)
      allow(CFPropertyList::List).to receive(:new)
        .with({ file: "path/Products/app_path/GoogleService-Info.plist" })
        .and_return(plist)
      allow(plist).to receive(:value)
        .and_return(identifier)

      # First call to CFProperty parses the application path.
      expect(CFPropertyList).to receive(:native_types)
        .and_return(app_path)
      # Second call uses the application path to find the Google service plist where the app id is stored
      expect(CFPropertyList).to receive(:native_types)
        .and_return(identifier)
      expect(helper.get_ios_app_id_from_archive("path")).to eq("identifier")
    end
  end
end
