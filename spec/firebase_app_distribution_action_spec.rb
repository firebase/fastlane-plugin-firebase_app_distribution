require 'fastlane/action'

describe Fastlane::Actions::FirebaseAppDistributionAction do
  let(:action) { Fastlane::Actions::FirebaseAppDistributionAction }
  let(:ios_app_id) { '1:1234567890:ios:321abc456def7890' }
  let(:ios_app_name) { 'projects/1234567890/apps/1:1234567890:ios:321abc456def7890' }
  let(:android_app_id) { '1:1234567890:android:321abc456def7890' }
  let(:android_app_name) { 'projects/1234567890/apps/1:1234567890:android:321abc456def7890' }

  describe '#platform_from_app_id' do
    it 'returns :android for an Android app' do
      expect(action.platform_from_app_id(android_app_id)).to eq(:android)
    end

    it 'returns :ios for an iOS app' do
      expect(action.platform_from_app_id(ios_app_id)).to eq(:ios)
    end

    it 'returns nil for a Web app' do
      expect(action.platform_from_app_id('1:65211879909:web:3ae38ef1cdcb2e01fe5f0c')).to be_nil
    end
  end

  describe '#get_binary_path' do
    describe 'with an iOS app' do
      it 'returns the value for ipa_path' do
        expect(action.get_binary_path(:ios, { app: ios_app_id, ipa_path: 'binary.ipa' })).to eq('binary.ipa')
      end

      it 'attempts to find them most recent ipa' do
        allow(Dir).to receive('[]').with('*.ipa').and_return(['binary.ipa'])
        allow(File).to receive(:mtime).and_return(0)
        expect(action.get_binary_path(:ios, { app: ios_app_id })).to eq('binary.ipa')
      end
    end

    describe 'with an Android app' do
      before { allow(Fastlane::Actions.lane_context).to receive('[]') }

      it 'returns the value for apk_path for an Android app' do
        expect(action.get_binary_path(:android, { app: android_app_id, apk_path: 'binary.apk' })).to eq('binary.apk')
      end

      it 'returns the value for android_artifact_path for an Android app' do
        expect(action.get_binary_path(:android, { app: android_app_id, android_artifact_path: 'binary.apk' })).to eq('binary.apk')
      end

      describe 'when android_artifact_type is not set' do
        let(:params) { { app: android_app_id } }

        it 'returns SharedValues::GRADLE_APK_OUTPUT_PATH value' do
          allow(Fastlane::Actions.lane_context).to receive('[]').with(Fastlane::Actions::SharedValues::GRADLE_APK_OUTPUT_PATH).and_return('binary.apk')
          expect(action.get_binary_path(:android, params)).to eq('binary.apk')
        end

        it 'attempts to find apk in current director and returns value' do
          allow(Dir).to receive('[]').with('*.apk').and_return(['first-binary.apk', 'last-binary.apk'])
          expect(action.get_binary_path(:android, params)).to eq('last-binary.apk')
        end

        it 'attempts to find apk in output folder and returns value' do
          allow(Dir).to receive('[]').with('*.apk').and_return([])
          allow(Dir).to receive('[]').with('app/build/outputs/apk/release/app-release.apk').and_return(['first-binary.apk', 'last-binary.apk'])
          expect(action.get_binary_path(:android, params)).to eq('last-binary.apk')
        end
      end

      describe 'when android_artifact_type equals APK' do
        let(:params) { { app: android_app_id, android_artifact_type: 'APK' } }

        it 'returns SharedValues::GRADLE_APK_OUTPUT_PATH value' do
          allow(Fastlane::Actions.lane_context).to receive('[]').with(Fastlane::Actions::SharedValues::GRADLE_APK_OUTPUT_PATH).and_return('binary.apk')
          expect(action.get_binary_path(:android, params)).to eq('binary.apk')
        end

        it 'attempts to find apk in current director and returns value' do
          allow(Dir).to receive('[]').with('*.apk').and_return(['first-binary.apk', 'last-binary.apk'])
          expect(action.get_binary_path(:android, params)).to eq('last-binary.apk')
        end

        it 'attempts to find apk in output folder and returns value' do
          allow(Dir).to receive('[]').with('*.apk').and_return([])
          allow(Dir).to receive('[]').with('app/build/outputs/apk/release/app-release.apk').and_return(['first-binary.apk', 'last-binary.apk'])
          expect(action.get_binary_path(:android, params)).to eq('last-binary.apk')
        end
      end

      describe 'when android_artifact_type equals AAB' do
        let(:params) { { app: android_app_id, android_artifact_type: 'AAB' } }

        it 'returns SharedValues::GRADLE_AAB_OUTPUT_PATH value' do
          allow(Fastlane::Actions.lane_context).to receive('[]').with(Fastlane::Actions::SharedValues::GRADLE_AAB_OUTPUT_PATH).and_return('binary.aab')
          expect(action.get_binary_path(:android, params)).to eq('binary.aab')
        end

        it 'attempts to find apk in current director and returns value' do
          allow(Dir).to receive('[]').with('*.aab').and_return(['first-binary.aab', 'last-binary.aab'])
          expect(action.get_binary_path(:android, params)).to eq('last-binary.aab')
        end

        it 'attempts to find apk in output folder and returns value' do
          allow(Dir).to receive('[]').with('*.aab').and_return([])
          allow(Dir).to receive('[]').with('app/build/outputs/bundle/release/app-release.aab').and_return(['first-binary.aab', 'last-binary.aab'])
          expect(action.get_binary_path(:android, params)).to eq('last-binary.aab')
        end
      end
    end
  end

  describe '#xcode_archive_path' do
    it 'returns the archive path is set, and platform is not Android' do
      allow(Fastlane::Actions).to receive(:lane_context).and_return({
        XCODEBUILD_ARCHIVE: '/path/to/archive'
      })
      expect(action.xcode_archive_path).to eq('/path/to/archive')
    end

    it 'returns nil if platform is Android' do
      allow(Fastlane::Actions).to receive(:lane_context).and_return({
        XCODEBUILD_ARCHIVE: '/path/to/archive',
        PLATFORM_NAME: :android
      })
      expect(action.xcode_archive_path).to be_nil
    end

    it 'returns nil if the archive path is not set' do
      allow(Fastlane::Actions).to receive(:lane_context).and_return({})
      expect(action.xcode_archive_path).to be_nil
    end
  end

  describe '#app_id_from_params' do
    it 'returns the app id from the app parameter if set' do
      expect(action).not_to(receive(:xcode_archive_path))

      params = { app: 'app-id' }
      result = action.app_id_from_params(params)

      expect(result).to eq('app-id')
    end

    it 'raises if the app parameter is not set and there is no archive path' do
      allow(action).to receive(:xcode_archive_path).and_return(nil)

      params = {}
      expect { action.app_id_from_params(params) }
        .to raise_error(ErrorMessage::MISSING_APP_ID)
    end

    it 'returns the app id from the plist if the archive path is set' do
      allow(action).to receive(:xcode_archive_path).and_return('/path/to/archive')
      allow(action).to receive(:get_ios_app_id_from_archive_plist)
        .with('/path/to/archive', '/path/to/plist')
        .and_return('app-id-from-plist')

      params = { googleservice_info_plist_path: '/path/to/plist' }
      result = action.app_id_from_params(params)

      expect(result).to eq('app-id-from-plist')
    end

    it 'raises if the app parameter is not set and the plist is empty' do
      allow(action).to receive(:xcode_archive_path).and_return('/path/to/archive')
      allow(action).to receive(:get_ios_app_id_from_archive_plist)
        .with('/path/to/archive', '/path/to/plist')
        .and_return(nil)

      params = { googleservice_info_plist_path: '/path/to/plist' }
      expect { action.app_id_from_params(params) }
        .to raise_error(ErrorMessage::MISSING_APP_ID)
    end
  end

  describe '#release_notes' do
    before do
      allow(Fastlane::Actions.lane_context).to receive('[]')
        .with(Fastlane::Actions::SharedValues::FL_CHANGELOG)
        .and_return('changelog-content')
    end

    describe 'when no release notes are set' do
      let(:params) { {} }
      it 'defaults to changelog' do
        expect(action.release_notes(params)).to eq('changelog-content')
      end
    end

    describe 'when only release_notes_file is set' do
      let(:params) { { release_notes_file: 'release-notes-file-path' } }
      let(:fake_file) { double('File') }

      it 'uses release_notes_file' do
        expect(fake_file).to receive(:read).and_return('release-notes-file-content')
        expect(File).to receive(:open).with('release-notes-file-path').and_return(fake_file)
        expect(action.release_notes(params)).to eq('release-notes-file-content')
      end
    end

    describe 'when release_notes and release_notes_file are set' do
      let(:params) do
        {
          release_notes: 'release-notes-content',
          release_notes_file: 'release-notes-file-path'
        }
      end

      it 'uses release_notes' do
        expect(action.release_notes(params)).to eq('release-notes-content')
      end
    end
  end

  describe '#run' do
    let(:params) do
      {
        app: ios_app_id,
        ipa_path: 'debug.ipa'
      }
    end

    before(:each) do
      allow(File).to receive(:exist?).and_call_original
      allow(action).to receive(:get_authorization).and_return(double('authorization', access_token: 'access-token'))
    end

    it 'raises error if it cannot find a valid binary path' do
      expect do
        action.run(params.merge(ipa_path: nil))
      end.to raise_error("Couldn't find binary")
    end

    it 'raises error if binary does not exist' do
      expect do
        action.run(params)
      end.to raise_error("Couldn't find binary at path debug.ipa")
    end

    describe 'with android app' do
      describe 'with AAB' do
        let(:params) do
          {
            app: android_app_id,
            android_artifact_path: 'debug.aab'
          }
        end

        before { allow(File).to receive(:exist?).with('debug.aab').and_return(true) }

        it 'raises user error if request returns a 404' do
          allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
            .to receive(:get_project_app_aab_info)
            .and_raise(Google::Apis::Error.new({}, status_code: '404'))

          expect do
            action.run(params)
          end.to raise_error(ErrorMessage::INVALID_APP_ID)
        end

        def stub_get_aab_info(integration_state = 'INTEGRATED')
          allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
            .to receive(:get_project_app_aab_info)
            .with("#{android_app_name}/aabInfo")
            .and_return(Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1AabInfo.new(integration_state: integration_state))
        end

        it 'raises error if play account is not linked' do
          stub_get_aab_info('PLAY_ACCOUNT_NOT_LINKED')

          expect do
            action.run(params)
          end.to raise_error(ErrorMessage::PLAY_ACCOUNT_NOT_LINKED)
        end

        it 'raises error if app not published' do
          stub_get_aab_info('APP_NOT_PUBLISHED')

          expect do
            action.run(params)
          end.to raise_error(ErrorMessage::APP_NOT_PUBLISHED)
        end

        it 'raises error if no matching app in play account' do
          stub_get_aab_info('NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT')

          expect do
            action.run(params)
          end.to raise_error(ErrorMessage::NO_APP_WITH_GIVEN_BUNDLE_ID_IN_PLAY_ACCOUNT)
        end

        it 'raises error if terms have not been accepted' do
          stub_get_aab_info('PLAY_IAS_TERMS_NOT_ACCEPTED')

          expect do
            action.run(params)
          end.to raise_error(ErrorMessage::PLAY_IAS_TERMS_NOT_ACCEPTED)
        end

        it 'raises error if aab state is unrecognized' do
          stub_get_aab_info('UNKNOWN')

          expect do
            action.run(params)
          end.to raise_error(ErrorMessage.aab_upload_error('UNKNOWN'))
        end
      end

      describe 'with a successful upload' do
        let(:fake_binary_contents) { "Hello World" }
        let(:fake_binary) { double("Binary") }

        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:open)
            .and_return(fake_binary)
          allow(fake_binary).to receive(:read)
            .and_return(fake_binary_contents)
        end

        it 'crashes if it exceeds polling threshold' do
          stub_const('Fastlane::Actions::FirebaseAppDistributionAction::MAX_POLLING_RETRIES', 0)
          allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
            .to receive(:http)
            .and_return({ name: 'operation-name' }.to_json)
          allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
            .to receive(:get_project_app_release_operation)
            .with('operation-name')
            .and_return(Google::Apis::FirebaseappdistributionV1::GoogleLongrunningOperation.new(
                          done: false
            ))

          expect do
            action.run({
                         app: android_app_id,
                         android_artifact_path: 'path/to.apk'
                       })
          end.to raise_error(FastlaneCore::Interface::FastlaneCrash)
        end

        describe 'when binary is processed' do
          let(:release) { { name: "release-name", displayVersion: 'display-version' } }

          before do
            allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
              .to receive(:http)
              .and_return({ name: 'operation-name', result: release }.to_json)
            allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
              .to receive(:get_project_app_release_operation)
              .and_return(Google::Apis::FirebaseappdistributionV1::GoogleLongrunningOperation.new(
                            done: true,
                            response: {
                              'release' => release
                            }
              ))
          end

          it 'returns release and updates FIREBASE_APP_DISTRO_RELEASE' do
            expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService).to_not(receive(:distribute_project_app_release))
            expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService).to_not(receive(:patch_project_app_release))

            action.run({
                         app: android_app_id,
                         android_artifact_path: 'path/to.apk'
                       })

            expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::FIREBASE_APP_DISTRO_RELEASE]).to eq(release)
          end

          describe 'when distributing to testers' do
            it 'raises error if request returns a 400' do
              allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release)
                .and_raise(Google::Apis::Error.new({}, status_code: '400'))

              expect do
                action.run({
                             app: android_app_id,
                             android_artifact_path: 'path/to.apk',
                             groups: "test-group-1, test-group-2",
                             testers: "user1@example.com, user2@example.com"
                           })
              end.to raise_error("#{ErrorMessage::INVALID_TESTERS}\nEmails: [\"user1@example.com\", \"user2@example.com\"] \nGroup Aliases: [\"test-group-1\", \"test-group-2\"]")
            end

            it 'distributes to testers, returns release and updates FIREBASE_APP_DISTRO_RELEASE' do
              allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release)
              expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release) do |_, release_name, request|
                expect(request.tester_emails).to eq(%w[user1@example.com user2@example.com])
                # Response will fail if tester_emails or group_aliases field is nil
                # it sets absent values to empty arrays
                expect(request.group_aliases).to eq([])
              end
              expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to_not(receive(:patch_project_app_release))

              returned_release = action.run({
                                              app: android_app_id,
                                              android_artifact_path: 'path/to.apk',
                                              testers: "user1@example.com, user2@example.com"
                                            })

              expect(returned_release).to eq(release)
              expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::FIREBASE_APP_DISTRO_RELEASE]).to eq(release)
            end

            it 'distributes to groups, returns release and updates FIREBASE_APP_DISTRO_RELEASE' do
              allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release)
              expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release) do |_, release_name, request|
                expect(request.group_aliases).to eq(%w[test-group-1 test-group-2])
                # Response will fail if tester_emails or group_aliases field is nil
                # it sets absent values to empty arrays
                expect(request.tester_emails).to eq([])
              end
              expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to_not(receive(:patch_project_app_release))

              returned_release = action.run({
                                              app: android_app_id,
                                              android_artifact_path: 'path/to.apk',
                                              groups: "test-group-1, test-group-2"
                                            })

              expect(returned_release).to eq(release)
              expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::FIREBASE_APP_DISTRO_RELEASE]).to eq(release)
            end

            it 'distributes to groups and testers, returns release and updates FIREBASE_APP_DISTRO_RELEASE' do
              allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release)
              expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release) do |_, release_name, request|
                expect(request.group_aliases).to eq(%w[test-group-1 test-group-2])
                expect(request.tester_emails).to eq(%w[user1@example.com user2@example.com])
              end
              expect_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to_not(receive(:patch_project_app_release))

              returned_release = action.run({
                                              app: android_app_id,
                                              android_artifact_path: 'path/to.apk',
                                              groups: "test-group-1, test-group-2",
                                              testers: "user1@example.com, user2@example.com"
                                            })

              expect(returned_release).to eq(release)
              expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::FIREBASE_APP_DISTRO_RELEASE]).to eq(release)
            end
          end

          describe 'when updating release notes' do
            it 'raises error if request returns a 400' do
              allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:patch_project_app_release)
                .and_raise(Google::Apis::Error.new({}, status_code: '400', body: 'release notes too long'))

              expect do
                action.run({
                             app: android_app_id,
                             android_artifact_path: 'path/to.apk',
                             release_notes: 'updated'
                           })
              end.to raise_error("#{ErrorMessage::INVALID_RELEASE_NOTES}: release notes too long")
            end

            it 'distributes to groups and testers, returns release and updates FIREBASE_APP_DISTRO_RELEASE' do
              updated_release = release.merge({ releaseNotes: { text: 'updated' } })
              allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:patch_project_app_release)
                .and_return(Google::Apis::FirebaseappdistributionV1::GoogleFirebaseAppdistroV1Release.from_json(updated_release.to_json))
              allow_any_instance_of(Google::Apis::FirebaseappdistributionV1::FirebaseAppDistributionService)
                .to receive(:distribute_project_app_release)

              returned_release = action.run({
                                              app: android_app_id,
                                              android_artifact_path: 'path/to.apk',
                                              release_notes: 'updated'
                                            })

              expect(returned_release).to eq(updated_release)
              expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::FIREBASE_APP_DISTRO_RELEASE]).to eq(updated_release)
            end
          end
        end
      end
    end
  end
end
