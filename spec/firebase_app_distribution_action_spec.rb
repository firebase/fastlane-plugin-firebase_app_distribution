describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionAction }
  describe '#platform_from_path' do
    it 'returns :android when the binary is an APK' do
      expect(action.platform_from_path('/path/to/your_binary.apk')).to eq(:android)
    end

    it 'returns :ios when the binary is an IPA' do
      expect(action.platform_from_path('/path/to/your_binary.ipa')).to eq(:ios)
    end

    it 'returns nil when the binary is neither IPA nor APK' do
      expect(action.platform_from_path('/path/to/your_binary.txt')).to be_nil
    end

    it 'returns nil when the binary path is nil' do
      expect(action.platform_from_path(nil)).to be_nil
    end
  end
end
