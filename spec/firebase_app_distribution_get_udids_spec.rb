require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionGetUdidsAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionGetUdidsAction }
  let(:app_id) { '1:1234567890:android:321abc456def7890' }
  let(:mock_file) { StringIO.new() }
  let(:output_file_path) { '/path/to/output/file.txt' }

  describe '#run' do
    before(:each) do
      allow(action).to receive(:fetch_auth_token).and_return('fake-auth-token')
      allow_any_instance_of(Fastlane::Client::FirebaseAppDistributionApiClient)
        .to receive(:get_udids)
        .with(app_id)
        .and_return([
          {
            udid: 'device-udid-1',
            name: 'device-name-1',
            platform: 'ios',
          },
          {
            udid: 'device-udid-2',
            name: 'device-name-2',
            platform: 'ios',
          },
        ])
    end

    let(:params) do
      {
        app: app_id,
        output_file: output_file_path,
      }
    end

    it 'writes UDIDs to file' do
      expect(File).to receive(:open).with(output_file_path, 'w').and_yield(mock_file)
      action.run(params)
      expect(mock_file.string).to eq(
        "Device ID\tDevice Name\tDevice Platform\n" + 
        "device-udid-1\tdevice-name-1\tios\n" +
        "device-udid-2\tdevice-name-2\tios\n"
      )
    end
  end
end
