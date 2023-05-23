require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionAddTesterGroupsAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionAddTesterGroupsAction }
  describe '#run' do
    before(:each) do
      allow(action).to receive(:fetch_auth_token).and_return('fake-auth-token')
    end

    it 'raises an error if the file argument is blank' do
      expect { action.run({ project_number: 1 }) }
        .to raise_error("Must specify `file`.")
    end

    it 'raises an error if the JSON file is not found' do
      nonexistent_file_path = 'path/to/nonexistent/file'
      allow(File).to receive(:open)
        .with(nonexistent_file_path)
        .and_raise(Errno::ENOENT)
      expect { action.run({ project_number: 1, file: nonexistent_file_path }) }
        .to raise_error("JSON file not found: #{nonexistent_file_path}")
    end

    it 'raises an error if the JSON file is invalid' do
      invalid_json_file_content = { "groups" => [
        {
          "alias" => "group1",
          # Required property "displayName" is missing
          "testers" => %w[user1@test.com user2@test.com]
        }
      ] }
      json_file_path = 'path/to/groups/json'
      mock_json_file = double('file')
      allow(File).to receive(:open)
        .with(json_file_path)
        .and_return(mock_json_file)
      allow(mock_json_file).to receive(:read).and_return(invalid_json_file_content.to_json)
      expect { action.run({ project_number: 1, file: json_file_path }) }
        .to raise_error("Invalid JSON file content. The property '#/groups/0' did not contain a required property of 'displayName'")
    end

    it 'succeeds and makes calls with values from JSON file' do
      project_number = 1
      tester_emails = %w[user1@test.com user2@test.com]
      group_alias = "group_alias"
      display_name = "Display name"
      json_file_content = { groups: [
        {
          alias: group_alias,
          displayName: display_name,
          testers: tester_emails
        }
      ] }
      json_file_path = 'path/to/groups/json'
      mock_json_file = double('file')
      allow(File).to receive(:open)
        .with(json_file_path)
        .and_return(mock_json_file)
      allow(mock_json_file).to receive(:read).and_return(json_file_content.to_json)

      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:create_group).with(project_number, group_alias, display_name)
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:add_testers_to_group).with(project_number, group_alias, tester_emails)
      action.run({ project_number: 1, file: json_file_path })
    end
  end
end
