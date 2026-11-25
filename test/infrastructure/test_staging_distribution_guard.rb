# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require 'json'

require_relative '../../android/fastlane/staging_distribution_guard'

class TestStagingDistributionGuard < Minitest::Test
  SYNTHETIC_BUCKET = 'study-buddy-54266.firebasestorage.app'
  VALID_APP_ID = '1:194789753908:android:a1b2c3d4e5f6'

  def setup
    @tmp_dir = Dir.mktmpdir('staging_guard_test')
    @repo_root = File.expand_path('../..', __dir__)
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir) if File.exist?(@tmp_dir)
  end

  def write_fixture(filename, content)
    path = File.join(@tmp_dir, filename)
    File.write(path, content.is_a?(String) ? content : JSON.pretty_generate(content))
    path
  end

  def valid_android_config(bucket = SYNTHETIC_BUCKET, app_id = VALID_APP_ID)
    {
      'project_info' => {
        'project_number' => '194789753908',
        'project_id' => 'study-buddy-54266',
        'storage_bucket' => bucket
      },
      'client' => [
        {
          'client_info' => {
            'mobilesdk_app_id' => app_id,
            'android_client_info' => {
              'package_name' => 'com.example.chat_app.staging'
            }
          }
        }
      ]
    }
  end

  def valid_dart_options(bucket = SYNTHETIC_BUCKET)
    <<~DART
      class DefaultFirebaseOptions {
        static const android = FirebaseOptions(storageBucket: '#{bucket}');
        static const ios = FirebaseOptions(storageBucket: '#{bucket}');
      }
    DART
  end

  def valid_runtime_wrapper(bucket = SYNTHETIC_BUCKET)
    bucket_str = bucket.nil? ? 'null' : "'#{bucket}'"
    <<~DART
      class DefaultFirebaseOptionsStaging {
        static const String expectedProjectId = 'study-buddy-54266';
        static const String expectedProjectNumber = '194789753908';
        static const String? authoritativeStorageBucket = #{bucket_str};
      }
    DART
  end

  # Case 1: Missing expected bucket fails
  def test_1_missing_expected_bucket_fails
    gs_path = write_fixture('google-services.json', valid_android_config)
    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: nil,
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path
      )
    end
    assert_match(/Missing required environment variable EXPECTED_STAGING_STORAGE_BUCKET/, err.message)
  end

  # Case 2: Empty expected bucket fails
  def test_2_empty_expected_bucket_fails
    gs_path = write_fixture('google-services.json', valid_android_config)
    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: '   ',
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path
      )
    end
    assert_match(/Missing required environment variable EXPECTED_STAGING_STORAGE_BUCKET/, err.message)
  end

  # Case 3: Production bucket fails
  def test_3_production_bucket_fails
    gs_path = write_fixture('google-services.json', valid_android_config('chat-app-28ac0.firebasestorage.app'))
    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: 'chat-app-28ac0.firebasestorage.app',
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path
      )
    end
    assert_match(/cannot match Production storage bucket/, err.message)
  end

  # Case 4: Missing Google Services file fails
  def test_4_missing_google_services_file_fails
    non_existent = File.join(@tmp_dir, 'does_not_exist.json')
    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: SYNTHETIC_BUCKET,
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: non_existent
      )
    end
    assert_match(/Staging google-services\.json not found/, err.message)
  end

  # Case 5: Mismatched Android bucket fails
  def test_5_mismatched_android_bucket_fails
    gs_path = write_fixture('google-services.json', valid_android_config('mismatched-bucket.firebasestorage.app'))
    dart_path = write_fixture('options.dart', valid_dart_options(SYNTHETIC_BUCKET))
    wrapper_path = write_fixture('wrapper.dart', valid_runtime_wrapper(SYNTHETIC_BUCKET))

    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: SYNTHETIC_BUCKET,
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path,
        dart_generated_path: dart_path,
        dart_wrapper_path: wrapper_path
      )
    end
    assert_match(/Cross-file validation failed/, err.message)
    assert_match(/\[android\] Declared bucket/, err.message)
  end

  # Case 6: Mismatched Dart bucket fails
  def test_6_mismatched_dart_bucket_fails
    gs_path = write_fixture('google-services.json', valid_android_config(SYNTHETIC_BUCKET))
    dart_path = write_fixture('options.dart', valid_dart_options('mismatched-dart.firebasestorage.app'))
    wrapper_path = write_fixture('wrapper.dart', valid_runtime_wrapper(SYNTHETIC_BUCKET))

    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: SYNTHETIC_BUCKET,
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path,
        dart_generated_path: dart_path,
        dart_wrapper_path: wrapper_path
      )
    end
    assert_match(/Cross-file validation failed/, err.message)
    assert_match(/\[dart_generated\] Declared bucket/, err.message)
  end

  # Case 7: Runtime Wrapper bucket is null and fails
  def test_7_runtime_wrapper_null_bucket_fails
    gs_path = write_fixture('google-services.json', valid_android_config(SYNTHETIC_BUCKET))
    dart_path = write_fixture('options.dart', valid_dart_options(SYNTHETIC_BUCKET))
    wrapper_path = write_fixture('wrapper.dart', valid_runtime_wrapper(nil))

    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: SYNTHETIC_BUCKET,
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path,
        dart_generated_path: dart_path,
        dart_wrapper_path: wrapper_path
      )
    end
    assert_match(/authoritativeStorageBucket in Runtime Wrapper is null/, err.message)
  end

  # Case 8: Runtime Wrapper bucket differs from expected and fails
  def test_8_runtime_wrapper_different_bucket_fails
    gs_path = write_fixture('google-services.json', valid_android_config(SYNTHETIC_BUCKET))
    dart_path = write_fixture('options.dart', valid_dart_options(SYNTHETIC_BUCKET))
    wrapper_path = write_fixture('wrapper.dart', valid_runtime_wrapper('different-wrapper.firebasestorage.app'))

    err = assert_raises(StandardError) do
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: SYNTHETIC_BUCKET,
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path,
        dart_generated_path: dart_path,
        dart_wrapper_path: wrapper_path
      )
    end
    assert_match(/Cross-file validation failed/, err.message)
    assert_match(/\[dart_wrapper\] Declared bucket/, err.message)
  end

  # Case 9: All configuration identities match and validation succeeds
  def test_9_all_configuration_identities_match_succeeds
    gs_path = write_fixture('google-services.json', valid_android_config(SYNTHETIC_BUCKET))
    dart_path = write_fixture('options.dart', valid_dart_options(SYNTHETIC_BUCKET))
    wrapper_path = write_fixture('wrapper.dart', valid_runtime_wrapper(SYNTHETIC_BUCKET))

    result = StagingDistributionGuard.validate!(
      repo_root: @repo_root,
      expected_bucket: SYNTHETIC_BUCKET,
      staging_app_id: VALID_APP_ID,
      service_creds: 'dummy.json',
      testers: 'test@example.com',
      google_services_path: gs_path,
      dart_generated_path: dart_path,
      dart_wrapper_path: wrapper_path
    )
    assert_equal(true, result)
  end

  # Case 10: No Flutter build or distribution action is reached after a failed validation
  def test_10_no_flutter_build_action_reached_after_failed_validation
    clean_executed = false
    build_executed = false
    distribution_executed = false

    # Attempt to execute distribution sequence when Runtime Wrapper is null
    gs_path = write_fixture('google-services.json', valid_android_config(SYNTHETIC_BUCKET))
    dart_path = write_fixture('options.dart', valid_dart_options(SYNTHETIC_BUCKET))
    wrapper_path = write_fixture('wrapper.dart', valid_runtime_wrapper(nil))

    assert_raises(StandardError) do
      # 1. Validation guard runs first
      StagingDistributionGuard.validate!(
        repo_root: @repo_root,
        expected_bucket: SYNTHETIC_BUCKET,
        staging_app_id: VALID_APP_ID,
        service_creds: 'dummy.json',
        testers: 'test@example.com',
        google_services_path: gs_path,
        dart_generated_path: dart_path,
        dart_wrapper_path: wrapper_path
      )

      # 2. Downstream actions must NOT be reached
      clean_executed = true
      build_executed = true
      distribution_executed = true
    end

    refute clean_executed, 'flutter clean must never execute after failed validation'
    refute build_executed, 'flutter build apk must never execute after failed validation'
    refute distribution_executed, 'firebase_app_distribution must never execute after failed validation'
  end
end
