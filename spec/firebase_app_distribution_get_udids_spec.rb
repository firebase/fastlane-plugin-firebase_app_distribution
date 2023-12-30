require 'fastlane/action'
require 'google/apis/firebaseappdistribution_v1alpha'

describe Fastlane::Actions::FirebaseAppDistributionGetUdidsAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionGetUdidsAction }
  let(:project_number) { 1_234_567_890 }
  let(:app_id) { '1:1234567890:android:321abc456def7890' }
  let(:mock_file) { StringIO.new }
  let(:output_file_path) { '/path/to/output/file.txt' }

  describe '#run' do
    V1alphaApi = Google::Apis::FirebaseappdistributionV1alpha

    before do
      allow(action).to receive(:get_authorization).and_return(double("creds"))
    end

    describe 'when there are testers with udids' do
      before(:each) do
        response = V1alphaApi::GoogleFirebaseAppdistroV1alphaGetTesterUdidsResponse.new(
          tester_udids: [
            V1alphaApi::GoogleFirebaseAppdistroV1alphaTesterUdid.new(
              udid: 'device-udid-1',
              name: 'device-name-1',
              platform: 'ios'
            ),
            V1alphaApi::GoogleFirebaseAppdistroV1alphaTesterUdid.new(
              udid: 'device-udid-2',
              name: 'device-name-2',
              platform: 'ios'
            )
          ]
        )
        allow_any_instance_of(V1alphaApi::FirebaseAppDistributionService)
          .to receive(:get_project_tester_udids)
          .with('projects/1234567890')
          .and_return(response)
      end

      let(:params) do
        {
          app: app_id,
          output_file: output_file_path
        }
      end

      it 'writes UDIDs to file' do
        expect(File).to receive(:open).with(output_file_path, 'w').and_yield(mock_file)
        action.run(params)
        expect(mock_file.string).to eq("Device ID\tDevice Name\tDevice Platform\ndevice-udid-1\tdevice-name-1\tios\ndevice-udid-2\tdevice-name-2\tios\n")
      end
    end

    describe 'when there are no testers with udids' do
      before(:each) do
        response = V1alphaApi::GoogleFirebaseAppdistroV1alphaGetTesterUdidsResponse.new(
          tester_udids: []
        )
        allow_any_instance_of(V1alphaApi::FirebaseAppDistributionService)
          .to receive(:get_project_tester_udids)
          .with('projects/1234567890')
          .and_return(response)
      end

      let(:params) do
        {
          app: app_id,
          output_file: output_file_path
        }
      end

      it 'does not write to file' do
        allow(File).to receive(:open).and_yield(mock_file)
        action.run(params)
        expect(File).not_to(have_received(:open))
      end
    end
  end
end
