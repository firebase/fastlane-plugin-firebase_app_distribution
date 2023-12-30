require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionDeleteGroupAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionDeleteGroupAction }
  describe '#run' do
    V1ApiService = Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService

    let(:project_number) { 1 }
    let(:group_alias) { 'group-alias' }

    before(:each) do
      allow(action).to receive(:get_authorization).and_return('fake-auth-token')
    end

    it 'raises an error if the alias argument is blank' do
      expect { action.run({ project_number: 1, display_name: "Some group" }) }
        .to raise_error("Must specify `alias`.")
    end

    it 'raises a user error if request returns a 404' do
      allow_any_instance_of(V1ApiService)
        .to receive(:delete_project_group)
        .and_raise(Google::Apis::Error.new({}, status_code: '404'))

      expect do
        action.run({ project_number: project_number, alias: group_alias })
      end.to raise_error(ErrorMessage::INVALID_TESTER_GROUP)
    end

    it 'crashes if error is unhandled' do
      allow_any_instance_of(V1ApiService)
        .to receive(:delete_project_group)
        .and_raise(Google::Apis::Error.new({}, status_code: '500'))

      expect do
        action.run({ project_number: project_number, alias: group_alias })
      end.to raise_error(FastlaneCore::Interface::FastlaneCrash)
    end

    it 'succeeds and makes calls with the correct values' do
      allow_any_instance_of(V1ApiService)
        .to receive(:delete_project_group)
      expect_any_instance_of(V1ApiService)
        .to receive(:delete_project_group)
        .with("projects/#{project_number}/groups/#{group_alias}")
      action.run({ project_number: project_number, alias: group_alias })
    end
  end
end
