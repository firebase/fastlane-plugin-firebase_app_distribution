require 'fastlane/action'

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
      expect(action.binary_path_from_platform(:ios, '/ipa/path', '/apk/path', '/aab/path')).to eq('/ipa/path')
    end

    it 'returns the apk_path for an Android app' do
      expect(action.binary_path_from_platform(:android, '/ipa/path', '/apk/path', nil)).to eq('/apk/path')
    end

    it 'returns the apk_path for an Android app when apk_path and aab_path are provided' do
      expect(action.binary_path_from_platform(:android, '/ipa/path', '/apk/path', '/aab/path')).to eq('/apk/path')
    end

    it 'returns the aab_path for an Android app when there is no apk_path' do
      expect(action.binary_path_from_platform(:android, nil, nil, '/aab/path')).to eq('/aab/path')
    end

    it 'returns the ipa_path by default when there is no platform' do
      expect(action.binary_path_from_platform(nil, '/ipa/path', '/apk/path', '/aab/path')).to eq('/ipa/path')
    end

    it 'falls back on the apk_path when there is no platform and no ipa_path' do
      expect(action.binary_path_from_platform(nil, nil, '/apk/path', '/aab/path')).to eq('/apk/path')
    end

    it 'returns nil when there is no platform and no paths' do
      expect(action.binary_path_from_platform(nil, nil, nil, nil)).to eq(nil)
    end
  end

  describe '#xcode_archive_path' do
    it 'returns the archive path is set, and platform is not Android' do
      allow(Fastlane::Actions).to receive(:lane_context).and_return({
        XCODEBUILD_ARCHIVE: '/path/to/archive'
      })
      expect(action.xcode_archive_path).to eq('/path/to/archive')
    end

    it 'returns nil if platform is Android' do
      allow(Fastlane::Actions).to receive(:lane_context).and_return({
        XCODEBUILD_ARCHIVE: '/path/to/archive',
        PLATFORM_NAME: :android
      })
      expect(action.xcode_archive_path).to be_nil
    end

    it 'returns nil if the archive path is not set' do
      allow(Fastlane::Actions).to receive(:lane_context).and_return({})
      expect(action.xcode_archive_path).to be_nil
    end
  end

  describe '#app_id_from_params' do
    it 'returns the app id from the app parameter if set' do
      expect(action).not_to(receive(:xcode_archive_path))

      params = { app: 'app-id' }
      result = action.app_id_from_params(params)

      expect(result).to eq('app-id')
    end

    it 'raises if the app parameter is not set and there is no archive path' do
      allow(action).to receive(:xcode_archive_path).and_return(nil)

      params = {}
      expect { action.app_id_from_params(params) }
        .to raise_error(ErrorMessage::MISSING_APP_ID)
    end

    it 'returns the app id from the plist if the archive path is set' do
      allow(action).to receive(:xcode_archive_path).and_return('/path/to/archive')
      allow(action).to receive(:get_ios_app_id_from_archive_plist)
        .with('/path/to/archive', '/path/to/plist')
        .and_return('app-id-from-plist')

      params = { googleservice_info_plist_path: '/path/to/plist' }
      result = action.app_id_from_params(params)

      expect(result).to eq('app-id-from-plist')
    end

    it 'raises if the app parameter is not set and the plist is empty' do
      allow(action).to receive(:xcode_archive_path).and_return('/path/to/archive')
      allow(action).to receive(:get_ios_app_id_from_archive_plist)
        .with('/path/to/archive', '/path/to/plist')
        .and_return(nil)

      params = { googleservice_info_plist_path: '/path/to/plist' }
      expect { action.app_id_from_params(params) }
        .to raise_error(ErrorMessage::MISSING_APP_ID)
    end
  end
end
