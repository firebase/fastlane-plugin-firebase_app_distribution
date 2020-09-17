describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionAction }
  describe '#platform_from_app_id' do
    it 'returns :android for an Android app' do
      expect(action.platform_from_app_id('1:1234567890:android:321abc456def7890')).to eq(:android)
    end

    it 'returns :ios for an iOS app' do
      expect(action.platform_from_app_id('1:1234567890:ios:321abc456def7890')).to eq(:ios)
    end

    it 'returns nil for a Web app' do
      expect(action.platform_from_app_id('1:65211879909:web:3ae38ef1cdcb2e01fe5f0c')).to be_nil
    end
  end

  describe '#binary_path_from_platform' do
    it 'returns the ipa_path for an iOS app' do
      expect(action.binary_path_from_platform(:ios, '/ipa/path', '/apk/path')).to eq('/ipa/path')
    end

    it 'returns the apk_path for an Android app' do
      expect(action.binary_path_from_platform(:android, '/ipa/path', '/apk/path')).to eq('/apk/path')
    end

    it 'returns the ipa_path by default when there is no platform' do
      expect(action.binary_path_from_platform(nil, '/ipa/path', '/apk/path')).to eq('/ipa/path')
    end

    it 'falls back on the apk_path when there is no platform and no ipa_path' do
      expect(action.binary_path_from_platform(nil, nil, '/apk/path')).to eq('/apk/path')
    end

    it 'returns nil when there is no platform and no paths' do
      expect(action.binary_path_from_platform(nil, nil, nil)).to eq(nil)
    end
  end
end
