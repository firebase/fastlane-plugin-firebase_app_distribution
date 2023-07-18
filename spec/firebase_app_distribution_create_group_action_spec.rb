require 'fastlane/action'
require 'google/apis/firebaseappdistribution_v1'

describe Fastlane::Actions::FirebaseAppDistributionCreateGroupAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionCreateGroupAction }

  describe '#run' do
    before(:each) do
      allow(action).to receive(:get_authorization).and_return(double("creds"))
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

      group = Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1Group.new(
        name: "projects/#{project_number}/groups/#{group_alias}",
        display_name: display_name
      )
      allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
        .to receive(:create_project_group)
      expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
        .to receive(:create_project_group) do |_, parent, expected_group, args|
          expect(parent).to eq("projects/#{project_number}")
          expect(expected_group.name).to eq(group.name)
          expect(expected_group.display_name).to eq(group.display_name)
          expect(args[:group_id]).to eq(group_alias)
        end
      action.run({ project_number: project_number, alias: group_alias, display_name: display_name })
    end
  end
end
