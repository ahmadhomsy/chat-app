# frozen_string_literal: true

require 'json'
require 'open3'

module StagingDistributionGuard
  PROD_BUCKETS = [
    'chat-app-28ac0.firebasestorage.app',
    'chat-app-28ac0.appspot.com'
  ].freeze

  def self.fail_guard!(msg)
    if defined?(FastlaneCore::UI)
      FastlaneCore::UI.user_error!(msg)
    elsif defined?(UI)
      UI.user_error!(msg)
    else
      raise StandardError, msg
    end
  end

  def self.validate!(options = {})
    repo_root = options[:repo_root] || File.expand_path('../..', __dir__)
    expected_bucket = options[:expected_bucket] || ENV['EXPECTED_STAGING_STORAGE_BUCKET'] || ENV['STAGING_STORAGE_BUCKET']
    staging_app_id = options[:staging_app_id] || ENV['STAGING_FIREBASE_APP_ID']
    service_creds = options[:service_creds] || ENV['GOOGLE_APPLICATION_CREDENTIALS']
    testers = options[:testers] || ENV['STAGING_TESTERS']

    google_services_path = options[:google_services_path] || File.join(repo_root, 'android/app/src/staging/google-services.json')
    dart_generated_path = options[:dart_generated_path] || File.join(repo_root, 'lib/firebase_options_staging.generated.dart')
    dart_wrapper_path = options[:dart_wrapper_path] || File.join(repo_root, 'lib/firebase_options_staging.dart')
    ios_plist_path = options[:ios_plist_path]

    # 1. Require EXPECTED_STAGING_STORAGE_BUCKET
    # 2. Reject nil, empty, and whitespace-only values
    if expected_bucket.nil? || expected_bucket.to_s.strip.empty?
      fail_guard!("Missing required environment variable EXPECTED_STAGING_STORAGE_BUCKET (or STAGING_STORAGE_BUCKET) for staging distribution")
    end
    clean_expected_bucket = expected_bucket.to_s.strip

    # 3. Reject known Production bucket values
    if PROD_BUCKETS.include?(clean_expected_bucket)
      fail_guard!("EXPECTED_STAGING_STORAGE_BUCKET cannot match Production storage bucket: '#{clean_expected_bucket}'")
    end

    # App ID, credentials, testers validations
    if options.fetch(:check_credentials, true)
      if staging_app_id.nil? || staging_app_id.to_s.strip.empty?
        fail_guard!("Missing required environment variable STAGING_FIREBASE_APP_ID for staging distribution")
      end
      unless staging_app_id.to_s.start_with?('1:194789753908:android:')
        fail_guard!("STAGING_FIREBASE_APP_ID '#{staging_app_id}' is invalid: must begin with '1:194789753908:android:' (cannot accept iOS or non-staging app ID)")
      end
      if service_creds.nil? || service_creds.to_s.strip.empty?
        fail_guard!("Missing required environment variable GOOGLE_APPLICATION_CREDENTIALS for staging distribution")
      end
      if testers.nil? || testers.to_s.strip.empty?
        fail_guard!("Missing required environment variable STAGING_TESTERS for staging distribution")
      end
    end

    # 4. Validate android/app/src/staging/google-services.json exists
    unless File.exist?(google_services_path)
      fail_guard!("Staging google-services.json not found at #{google_services_path}")
    end

    # Validate google-services.json client App ID matches staging_app_id if check_credentials
    if options.fetch(:check_credentials, true) && staging_app_id
      begin
        gs_content = JSON.parse(File.read(google_services_path))
      rescue StandardError => e
        fail_guard!("Failed to parse google-services.json at #{google_services_path}: #{e.message}")
      end
      clients = gs_content['client'] || []
      staging_client = clients.find { |c| c.dig('client_info', 'android_client_info', 'package_name') == 'com.example.chat_app.staging' }
      gs_app_id = staging_client&.dig('client_info', 'mobilesdk_app_id')

      if gs_app_id.nil? || gs_app_id.strip.empty?
        fail_guard!("No matching client with package 'com.example.chat_app.staging' found in #{google_services_path}")
      end
      if gs_app_id != staging_app_id
        fail_guard!("STAGING_FIREBASE_APP_ID ('#{staging_app_id}') does not match mobilesdk_app_id in google-services.json ('#{gs_app_id}')")
      end
    end

    # 5, 6, 7 & 8: Execute cross-file consistency validation using repository-root-resolved paths
    # Reuses the canonical Node validator: tool/validate_staging_cross_file_consistency.js
    node_validator = File.join(repo_root, 'tool/validate_staging_cross_file_consistency.js')
    unless File.exist?(node_validator)
      fail_guard!("Cross-file validator not found at #{node_validator}")
    end

    env = {
      'EXPECTED_STAGING_STORAGE_BUCKET' => clean_expected_bucket,
      'STAGING_ANDROID_PATH' => google_services_path,
      'STAGING_DART_GENERATED_PATH' => dart_generated_path,
      'STAGING_DART_WRAPPER_PATH' => dart_wrapper_path
    }
    env['STAGING_IOS_PLIST_PATH'] = ios_plist_path if ios_plist_path

    cmd = ['node', node_validator, clean_expected_bucket]
    cmd << ios_plist_path if ios_plist_path

    stdout, stderr, status = Open3.capture3(env, *cmd)
    unless status.success?
      err_output = (stderr.to_s.empty? ? stdout : stderr).strip
      fail_guard!("Cross-file validation failed:\n#{err_output}")
    end

    true
  end
end
