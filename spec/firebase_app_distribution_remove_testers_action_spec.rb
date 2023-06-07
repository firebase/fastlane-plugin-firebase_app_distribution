require 'fastlane/action'
require 'fastlane_core/ui/ui'

describe Fastlane::Actions::FirebaseAppDistributionRemoveTestersAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionRemoveTestersAction }
  describe '#run' do
    before(:each) do
      allow(action).to receive(:fetch_auth_token).and_return('fake-auth-token')
    end

    it 'raises an error if emails and file are blank' do
      expect { action.run({ project_number: 1 }) }
        .to raise_error("Must specify `emails` or `file`.")
    end

    it 'raises an error if there are > 1000 emails' do
      emails = (1..1001).map { |i| "#{i}@e.mail" }.join(',')

      expect { action.run({ project_number: 1, emails: emails }) }
        .to raise_error("A maximum of 1000 testers can be removed at a time.")
    end

    it 'raises an error if there are no emails' do
      expect { action.run({ project_number: 1, emails: " " }) }
        .to raise_error("Must pass at least one email")
    end

    it 'succeeds and makes call with value from emails param' do
      project_number = 1
      emails = '1@e.mail,2@e.mail'
      path = 'path/to/file'
      count = 1
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:remove_testers).with(project_number, emails.split(',')).and_return(count)
      allow(FastlaneCore::UI).to receive(:success)
      expect(FastlaneCore::UI).to receive(:success).with("✅ #{count} tester(s) removed successfully.")

      action.run({ project_number: project_number, emails: emails, file: path })
    end

    it 'succeeds and makes call with value from file' do
      project_number = 1
      emails = '1@e.mail,2@e.mail'
      path = 'path/to/file'
      count = 1
      fake_file = double('file')
      allow(File).to receive(:open)
        .with(path)
        .and_return(fake_file)
      allow(fake_file).to receive(:read).and_return(emails)
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:remove_testers).with(project_number, emails.split(',')).and_return(count)
      allow(FastlaneCore::UI).to receive(:success)
      expect(FastlaneCore::UI).to receive(:success).with("✅ #{count} tester(s) removed successfully.")

      action.run({ project_number: project_number, file: path })
    end

    it 'removes testers only from the specified group when group_alias is specified' do
      project_number = 1
      emails = '1@e.mail,2@e.mail'
      path = 'path/to/file'
      fake_file = double('file')
      group_alias = 'group_alias'
      allow(File).to receive(:open)
        .with(path)
        .and_return(fake_file)
      allow(fake_file).to receive(:read).and_return(emails)
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).not_to(receive(:remove_testers))
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:remove_testers_from_group).with(project_number, group_alias, emails.split(','))
      action.run({ project_number: project_number, file: path, group_alias: group_alias })
    end

    it 'does not makes any remove_testers_from_group calls when group_alias is not specified' do
      project_number = 1
      emails = '1@e.mail,2@e.mail'
      path = 'path/to/file'
      fake_file = double('file')
      allow(File).to receive(:open)
        .with(path)
        .and_return(fake_file)
      allow(fake_file).to receive(:read).and_return(emails)
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).to receive(:remove_testers).with(project_number, emails.split(','))
      expect_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient).not_to(receive(:remove_testers_from_group))
      action.run({ project_number: project_number, file: path })
    end
  end
end
