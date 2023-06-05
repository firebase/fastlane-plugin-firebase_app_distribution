require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionCreateGroupAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionCreateGroupAction }
  describe '#run' do
    before(:each) do
      allow(action).to receive(:fetch_auth_token).and_return('fake-auth-token')
    end

    it 'raises an error if the alias argument is blank' do
      expect { action.run({ project_number: 1, display_name: "Some group" }) }
        .to raise_error("Must specify `alias`.")
    end

    it 'raises an error if the display_name argument is blank' do
      expect { action.run({ project_number: 1, alias: "some-alias" }) }
        .to raise_error("Must specify `display_name`.")
    end

    it 'succeeds and makes calls with the correct values' do
      project_number = 1
      group_alias = "group_alias"
      display_name = "Display name"
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:create_group).with(project_number, group_alias, display_name)
      action.run({ project_number: 1, alias: group_alias, display_name: display_name })
    end
  end
end
