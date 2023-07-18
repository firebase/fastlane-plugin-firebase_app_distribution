require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionDeleteGroupAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionDeleteGroupAction }
  describe '#run' do
    before(:each) do
      allow(action).to receive(:get_authorization).and_return('fake-auth-token')
    end

    it 'raises an error if the alias argument is blank' do
      expect { action.run({ project_number: 1, display_name: "Some group" }) }
        .to raise_error("Must specify `alias`.")
    end

    it 'succeeds and makes calls with the correct values' do
      project_number = 1
      group_alias = "group_alias"

      allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
        .to receive(:delete_project_group)
      expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
        .to receive(:delete_project_group)
        .with("projects/#{project_number}/groups/#{group_alias}")
      action.run({ project_number: project_number, alias: group_alias })
    end
  end
end
