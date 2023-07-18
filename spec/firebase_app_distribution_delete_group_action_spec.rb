require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionDeleteGroupAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionDeleteGroupAction }
  describe '#run' do
    before(:each) do
      allow(action).to receive(:fetch_auth_token).and_return('fake-auth-token')
    end

    it 'raises an error if the alias argument is blank' do
      expect { action.run({ project_number: 1, display_name: "Some group" }) }
        .to raise_error("Must specify `alias`.")
    end

    it 'succeeds and makes calls with the correct values' do
      project_number = 1
      group_alias = "group_alias"
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:delete_group).with(project_number, group_alias)
      action.run({ project_number: 1, alias: group_alias })
    end
  end
end
