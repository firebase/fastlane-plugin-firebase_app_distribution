require 'fastlane/action'
require 'google/apis/firebaseappdistribution_v1'

FirebaseAppDistribution = Google::Apis::FirebaseappdistributionV1

describe Fastlane::Actions::FirebaseAppDistributionGetLatestReleaseAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionGetLatestReleaseAction }
  describe '#run' do
    before(:each) do
      allow(action).to receive(:get_authorization).and_return(double("creds"))
    end

    it 'returns nil if the app does not have any releases' do
      response = Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1ListReleasesResponse.new
      allow_any_instance_of(FirebaseAppDistribution::FirebaseAppDistributionService)
        .to receive(:list_project_app_releases)
        .with('projects/1234567890/apps/1:1234567890:ios:321abc456def7890', page_size: 1)
        .and_return(response)

      expect(action.run({ app: '1:1234567890:ios:321abc456def7890' })).to eq(nil)
      expect(Fastlane::Actions.lane_context[:FIREBASE_APP_DISTRO_LATEST_RELEASE]).to eq(nil)
    end

    it 'returns the release if the app has at least one release' do
      response = Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1ListReleasesResponse.new(
        releases: [
          FirebaseAppDistribution::GoogleFirebaseAppdistroV1Release.new(
            name: "projects/1234567890/apps/1:1234567890:ios:321abc456def7890/releases/0a1b2c3d4",
            release_notes: FirebaseAppDistribution::GoogleFirebaseAppdistroV1ReleaseNotes.new(
              text: "Here are some release notes!"
            ),
            display_version: "1.2.3",
            build_version: "10",
            binary_download_uri: "binary-download-uri",
            firebase_console_uri: "firebase-console-uri",
            testing_uri: "testing-uri",
            create_time: "2021-10-06T15:01:23Z"
          )
        ]
      )
      allow_any_instance_of(FirebaseAppDistribution::FirebaseAppDistributionService)
        .to receive(:list_project_app_releases)
        .with('projects/1234567890/apps/1:1234567890:ios:321abc456def7890', page_size: 1)
        .and_return(response)

      expected_hash = {
        name: "projects/1234567890/apps/1:1234567890:ios:321abc456def7890/releases/0a1b2c3d4",
        releaseNotes: {
          text: "Here are some release notes!"
        },
        displayVersion: "1.2.3",
        buildVersion: "10",
        binaryDownloadUri: "binary-download-uri",
        firebaseConsoleUri: "firebase-console-uri",
        testingUri: "testing-uri",
        createTime: "2021-10-06T15:01:23Z"
      }
      expect(action.run({ app: '1:1234567890:ios:321abc456def7890' })).to eq(expected_hash)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::FIREBASE_APP_DISTRO_LATEST_RELEASE])
        .to eq(expected_hash)
    end
  end
end
