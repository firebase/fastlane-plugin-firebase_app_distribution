require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionGetLatestReleaseAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionGetLatestReleaseAction }
  describe '#run' do
    before(:each) do
      allow(action).to receive(:fetch_auth_token).and_return('fake-auth-token')
    end

    it 'returns nil if the app does not have any releases' do
      allow_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:list_releases).with('projects/1234567890/apps/1:1234567890:ios:321abc456def7890', 1).and_return({})

      expect(action.run({ app: '1:1234567890:ios:321abc456def7890' })).to eq(nil)
      expect(Fastlane::Actions.lane_context[:FIREBASE_APP_DISTRO_LATEST_RELEASE]).to eq(nil)
    end

    it 'returns the release if the app has at least one release' do
      release = {
          name: "projects/1234567890/apps/1:1234567890:ios:321abc456def7890/releases/0a1b2c3d4",
        releaseNotes: {
          text: "Here are some release notes!"
        },
        displayVersion: "1.2.3",
        buildVersion: "10",
        createTime: "2021-10-06T15:01:23Z"
      }
      allow_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:list_releases).with('projects/1234567890/apps/1:1234567890:ios:321abc456def7890', 1).and_return({ releases: [release] })

      expect(action.run({ app: '1:1234567890:ios:321abc456def7890' })).to eq(release)
      expect(Fastlane::Actions.lane_context[:FIREBASE_APP_DISTRO_LATEST_RELEASE]).to eq(release)
    end
  end
end
