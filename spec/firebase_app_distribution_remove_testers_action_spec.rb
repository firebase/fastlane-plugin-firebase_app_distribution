require 'fastlane/action'
require 'fastlane_core/ui/ui'

describe Fastlane::Actions::FirebaseAppDistributionRemoveTestersAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionRemoveTestersAction }
  describe '#run' do
    FirebaseAppDistributionService = Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService

    let(:project_number) { 1 }
    let(:emails) { '1@e.mail,2@e.mail' }

    before(:each) do
      allow(action).to receive(:get_authorization).and_return('fake-auth-token')
      allow_any_instance_of(FirebaseAppDistributionService)
        .to receive(:batch_project_tester_remove)
        .and_return(Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1BatchRemoveTestersResponse.new(
                      emails: emails.split(',')
        ))
      allow_any_instance_of(FirebaseAppDistributionService)
        .to receive(:batch_project_group_leave)
      allow(FastlaneCore::UI).to receive(:success)
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
      expect_any_instance_of(FirebaseAppDistributionService)
        .to receive(:batch_project_tester_remove) { |_, parent, request|
          expect(parent).to eq("projects/#{project_number}")
          expect(request.emails).to eq(emails.split(','))
        }.and_return(Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1BatchRemoveTestersResponse.new(
                       emails: emails.split(',')
        ))
      expect(FastlaneCore::UI).to receive(:success).with("✅ #{emails.split(',').count} tester(s) removed successfully.")

      action.run({ project_number: project_number, emails: emails })
    end

    it 'succeeds and makes call with value from file' do
      path = 'path/to/file'
      fake_file = double('file')
      allow(File).to receive(:open)
        .with(path)
        .and_return(fake_file)
      allow(fake_file).to receive(:read).and_return(emails)

      expect_any_instance_of(FirebaseAppDistributionService)
        .to receive(:batch_project_tester_remove) { |_, parent, request|
          expect(parent).to eq("projects/#{project_number}")
          expect(request.emails).to eq(emails.split(','))
        }.and_return(Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1BatchRemoveTestersResponse.new(
                       emails: emails.split(',')
        ))
      expect(FastlaneCore::UI).to receive(:success).with("✅ #{emails.split(',').count} tester(s) removed successfully.")

      action.run({ project_number: project_number, file: path })
    end

    it 'removes testers only from the specified group when group_alias is specified' do
      group_alias = 'group_alias'

      expect_any_instance_of(FirebaseAppDistributionService)
        .to_not(receive(:batch_project_tester_remove))
      expect_any_instance_of(FirebaseAppDistributionService)
        .to receive(:batch_project_group_leave) do |_, name, request|
        expect(name).to eq("projects/#{project_number}/groups/#{group_alias}")
        expect(request.emails).to eq(emails.split(','))
      end

      action.run({ project_number: project_number, emails: emails, group_alias: group_alias })
    end

    it 'does not makes any batch_project_group_leave calls when group_alias is not specified' do
      expect_any_instance_of(FirebaseAppDistributionService)
        .to_not(receive(:batch_project_group_leave))

      action.run({ project_number: project_number, emails: emails })
    end
  end
end
