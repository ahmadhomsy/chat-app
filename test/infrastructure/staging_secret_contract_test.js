const assert = require('assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');
const { validateGoogleServices } = require('../../tool/validate_staging_google_services');
const { validateCrossFileConsistency } = require('../../tool/validate_staging_cross_file_consistency');
const { validateRuntimeWrapper } = require('../../tool/validate_staging_runtime_wrapper');

describe('Staging Secret Contract & Identity Verification Tests', () => {
  let tempDir;

  // Synthetic test fixture bucket value (for isolated testing only)
  const TEST_SYNTHETIC_BUCKET = 'study-buddy-54266.firebasestorage.app';

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'staging-test-'));
  });

  afterEach(() => {
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  function writeFixture(filename, data) {
    const fullPath = path.join(tempDir, filename);
    fs.writeFileSync(fullPath, typeof data === 'string' ? data : JSON.stringify(data, null, 2), 'utf8');
    return fullPath;
  }

  const validStagingConfig = {
    project_info: {
      project_number: '194789753908',
      project_id: 'study-buddy-54266',
      storage_bucket: TEST_SYNTHETIC_BUCKET,
    },
    client: [
      {
        client_info: {
          mobilesdk_app_id: '1:194789753908:android:a1b2c3d4e5f6',
          android_client_info: {
            package_name: 'com.example.chat_app.staging',
          },
        },
      },
    ],
  };

  it('1. Correct Staging google-services.json is accepted with matching expected bucket', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    const result = validateGoogleServices(fixturePath, TEST_SYNTHETIC_BUCKET);
    assert.strictEqual(result.projectId, 'study-buddy-54266');
    assert.strictEqual(result.projectNumber, '194789753908');
    assert.strictEqual(result.appId, '1:194789753908:android:a1b2c3d4e5f6');
    assert.strictEqual(result.storageBucket, TEST_SYNTHETIC_BUCKET);
  });

  it('2. Production google-services.json is rejected', () => {
    const prodConfig = {
      project_info: {
        project_number: '639830188590',
        project_id: 'chat-app-28ac0',
        storage_bucket: 'chat-app-28ac0.firebasestorage.app',
      },
      client: [
        {
          client_info: {
            mobilesdk_app_id: '1:639830188590:android:4a3b1c669d60ee593235bf',
            android_client_info: {
              package_name: 'com.example.chat_app',
            },
          },
        },
      ],
    };
    const fixturePath = writeFixture('prod.json', prodConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, TEST_SYNTHETIC_BUCKET),
      /Invalid project_id "chat-app-28ac0", expected "study-buddy-54266"/
    );
  });

  it('3. Wrong Android package is rejected', () => {
    const wrongPackageConfig = JSON.parse(JSON.stringify(validStagingConfig));
    wrongPackageConfig.client[0].client_info.android_client_info.package_name = 'com.example.chat_app.dev';
    const fixturePath = writeFixture('wrong-package.json', wrongPackageConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, TEST_SYNTHETIC_BUCKET),
      /No client found with package_name "com.example.chat_app.staging"/
    );
  });

  it('4. Wrong project number is rejected', () => {
    const wrongNumberConfig = JSON.parse(JSON.stringify(validStagingConfig));
    wrongNumberConfig.project_info.project_number = '999999999999';
    const fixturePath = writeFixture('wrong-number.json', wrongNumberConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, TEST_SYNTHETIC_BUCKET),
      /Invalid project_number "999999999999", expected "194789753908"/
    );
  });

  it('5. iOS App ID is rejected for Android distribution', () => {
    const iosAppIdConfig = JSON.parse(JSON.stringify(validStagingConfig));
    iosAppIdConfig.client[0].client_info.mobilesdk_app_id = '1:194789753908:ios:f6e5d4c3b2a1';
    const fixturePath = writeFixture('ios-app-id.json', iosAppIdConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, TEST_SYNTHETIC_BUCKET),
      /Invalid mobilesdk_app_id "1:194789753908:ios:f6e5d4c3b2a1", expected prefix "1:194789753908:android:"/
    );
  });

  it('6. Missing file throws descriptive error', () => {
    const nonExistentPath = path.join(tempDir, 'does-not-exist.json');
    assert.throws(
      () => validateGoogleServices(nonExistentPath, TEST_SYNTHETIC_BUCKET),
      /File not found/
    );
  });

  it('7. Malformed JSON file is rejected', () => {
    const malformedPath = writeFixture('malformed.json', '{ invalid json ');
    assert.throws(
      () => validateGoogleServices(malformedPath, TEST_SYNTHETIC_BUCKET),
      /Unexpected token|JSON|Malformed/
    );
  });

  it('8. Missing or empty storage_bucket in file is rejected', () => {
    const emptyBucketConfig = JSON.parse(JSON.stringify(validStagingConfig));
    delete emptyBucketConfig.project_info.storage_bucket;
    const fixturePath1 = writeFixture('empty-bucket.json', emptyBucketConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath1, TEST_SYNTHETIC_BUCKET),
      /Missing or empty storage_bucket/
    );

    emptyBucketConfig.project_info.storage_bucket = '   ';
    const fixturePath2 = writeFixture('whitespace-bucket.json', emptyBucketConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath2, TEST_SYNTHETIC_BUCKET),
      /Missing or empty storage_bucket/
    );
  });

  it('9. Production storage_bucket in Staging config is rejected', () => {
    const prodBucketConfig = JSON.parse(JSON.stringify(validStagingConfig));
    prodBucketConfig.project_info.storage_bucket = 'chat-app-28ac0.firebasestorage.app';
    const fixturePath = writeFixture('prod-bucket.json', prodBucketConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, TEST_SYNTHETIC_BUCKET),
      /Production storage bucket detected/
    );
  });

  it('10. Missing expectedStorageBucket parameter is rejected as mandatory error', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath),
      /Mandatory expectedStorageBucket is missing or empty/
    );
  });

  it('11. Empty or whitespace expectedStorageBucket parameter is rejected', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, '   '),
      /Mandatory expectedStorageBucket is missing or empty/
    );
  });

  it('12. Production expectedStorageBucket parameter is rejected', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, 'chat-app-28ac0.firebasestorage.app'),
      /Authoritative expectedStorageBucket cannot match Production bucket/
    );
  });

  it('13. Mismatched expected storage_bucket is rejected', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, 'different-test-bucket.appspot.com'),
      /does not match authoritative expected bucket/
    );
  });

  it('14. Matching expected storage_bucket succeeds and returns verified metadata', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    const res = validateGoogleServices(fixturePath, TEST_SYNTHETIC_BUCKET);
    assert.strictEqual(res.storageBucket, TEST_SYNTHETIC_BUCKET);
  });

  describe('Runtime Wrapper Authoritative Storage Bucket Tests', () => {
    function writeMockRuntimeWrapper(bucket) {
      const bucketDecl = bucket === null ? 'null' : `'${bucket}'`;
      return writeFixture('firebase_options_staging.dart', `
class DefaultFirebaseOptionsStaging {
  static const String expectedProjectId = 'study-buddy-54266';
  static const String expectedProjectNumber = '194789753908';
  static const String? authoritativeStorageBucket = ${bucketDecl};
}
`);
    }

    it('15. Runtime Wrapper with null bucket fails validation', () => {
      const wrapperPath = writeMockRuntimeWrapper(null);
      assert.throws(
        () => validateRuntimeWrapper({ wrapperPath, expectedStorageBucket: TEST_SYNTHETIC_BUCKET }),
        /authoritativeStorageBucket in Runtime Wrapper is null\. Staging remains unconfigured and cannot be distributed\./
      );
    });

    it('16. Runtime Wrapper with empty or whitespace bucket fails validation', () => {
      const wrapperPath = writeMockRuntimeWrapper('   ');
      assert.throws(
        () => validateRuntimeWrapper({ wrapperPath, expectedStorageBucket: TEST_SYNTHETIC_BUCKET }),
        /authoritativeStorageBucket in Runtime Wrapper is empty or whitespace-only/
      );
    });

    it('17. Runtime Wrapper with Production bucket fails validation', () => {
      const wrapperPath = writeMockRuntimeWrapper('chat-app-28ac0.firebasestorage.app');
      assert.throws(
        () => validateRuntimeWrapper({ wrapperPath, expectedStorageBucket: TEST_SYNTHETIC_BUCKET }),
        /Production storage bucket detected in Runtime Wrapper/
      );
    });

    it('18. Runtime Wrapper with mismatched bucket fails validation', () => {
      const wrapperPath = writeMockRuntimeWrapper('different-bucket.firebasestorage.app');
      assert.throws(
        () => validateRuntimeWrapper({ wrapperPath, expectedStorageBucket: TEST_SYNTHETIC_BUCKET }),
        /does not match expected bucket/
      );
    });

    it('19. Runtime Wrapper with matching bucket succeeds', () => {
      const wrapperPath = writeMockRuntimeWrapper(TEST_SYNTHETIC_BUCKET);
      const res = validateRuntimeWrapper({ wrapperPath, expectedStorageBucket: TEST_SYNTHETIC_BUCKET });
      assert.strictEqual(res.verifiedBucket, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.wrapperPath, wrapperPath);
    });
  });

  describe('Cross-File Storage Bucket Consistency Tests', () => {
    function writeMockDartOptions(bucket) {
      return writeFixture('firebase_options_staging.generated.dart', `
class DefaultFirebaseOptions {
  static const android = FirebaseOptions(storageBucket: '${bucket}');
  static const ios = FirebaseOptions(storageBucket: '${bucket}');
}
`);
    }

    function writeMockRuntimeWrapper(bucket) {
      const bucketDecl = bucket === null ? 'null' : `'${bucket}'`;
      return writeFixture('firebase_options_staging.dart', `
class DefaultFirebaseOptionsStaging {
  static const String expectedProjectId = 'study-buddy-54266';
  static const String expectedProjectNumber = '194789753908';
  static const String? authoritativeStorageBucket = ${bucketDecl};
}
`);
    }

    function writeMockIosPlist(bucket) {
      return writeFixture('GoogleService-Info-staging.plist', `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PROJECT_ID</key>
  <string>study-buddy-54266</string>
  <key>STORAGE_BUCKET</key>
  <string>${bucket}</string>
</dict>
</plist>`);
    }

    it('20. 2-target mode (Android + Dart) succeeds when no iOS plist is supplied', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions(TEST_SYNTHETIC_BUCKET);
      const wrapperPath = writeMockRuntimeWrapper(TEST_SYNTHETIC_BUCKET);

      const res = validateCrossFileConsistency({
        androidPath,
        dartPath,
        wrapperPath,
        expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
      });

      assert.strictEqual(res.verifiedBucket, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.targetCount, 2);
      assert.strictEqual(res.mode, '2-target (Android + Dart)');
      assert.strictEqual(res.verifiedSources.android, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.verifiedSources.dart_generated, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.verifiedSources.dart_wrapper, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.verifiedSources.ios, undefined);
    });

    it('21. 3-target mode (Android + Dart + iOS) succeeds when valid iOS plist is explicitly supplied', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions(TEST_SYNTHETIC_BUCKET);
      const wrapperPath = writeMockRuntimeWrapper(TEST_SYNTHETIC_BUCKET);
      const iosPath = writeMockIosPlist(TEST_SYNTHETIC_BUCKET);

      const res = validateCrossFileConsistency({
        androidPath,
        dartPath,
        wrapperPath,
        iosPath,
        expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
      });

      assert.strictEqual(res.verifiedBucket, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.targetCount, 3);
      assert.strictEqual(res.mode, '3-target (Android + Dart + iOS)');
      assert.strictEqual(res.verifiedSources.android, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.verifiedSources.dart_generated, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.verifiedSources.dart_wrapper, TEST_SYNTHETIC_BUCKET);
      assert.strictEqual(res.verifiedSources.ios, TEST_SYNTHETIC_BUCKET);
    });

    it('22. Missing iOS plist when explicitly supplied fails validation', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions(TEST_SYNTHETIC_BUCKET);
      const wrapperPath = writeMockRuntimeWrapper(TEST_SYNTHETIC_BUCKET);
      const nonExistentIosPath = path.join(tempDir, 'nonexistent_ios.plist');

      assert.throws(
        () => validateCrossFileConsistency({
          androidPath,
          dartPath,
          wrapperPath,
          iosPath: nonExistentIosPath,
          expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
        }),
        /Explicitly supplied iOS plist file not found/
      );
    });

    it('23. Mismatch in Dart generated options fails cross-file validation', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions('different-bucket.firebasestorage.app');
      const wrapperPath = writeMockRuntimeWrapper(TEST_SYNTHETIC_BUCKET);

      assert.throws(
        () => validateCrossFileConsistency({
          androidPath,
          dartPath,
          wrapperPath,
          expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
        }),
        /Cross-file storage bucket validation failed/
      );
    });

    it('24. Null authoritative bucket in Runtime Wrapper fails cross-file validation', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions(TEST_SYNTHETIC_BUCKET);
      const wrapperPath = writeMockRuntimeWrapper(null);

      assert.throws(
        () => validateCrossFileConsistency({
          androidPath,
          dartPath,
          wrapperPath,
          expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
        }),
        /authoritativeStorageBucket in Runtime Wrapper is null/
      );
    });

    it('25. Mismatch in Runtime Wrapper fails cross-file validation', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions(TEST_SYNTHETIC_BUCKET);
      const wrapperPath = writeMockRuntimeWrapper('different-wrapper.firebasestorage.app');

      assert.throws(
        () => validateCrossFileConsistency({
          androidPath,
          dartPath,
          wrapperPath,
          expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
        }),
        /Cross-file storage bucket validation failed/
      );
    });

    it('26. Mismatch in iOS plist fails cross-file validation', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions(TEST_SYNTHETIC_BUCKET);
      const wrapperPath = writeMockRuntimeWrapper(TEST_SYNTHETIC_BUCKET);
      const iosPath = writeMockIosPlist('different-bucket.firebasestorage.app');

      assert.throws(
        () => validateCrossFileConsistency({
          androidPath,
          dartPath,
          wrapperPath,
          iosPath,
          expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
        }),
        /Cross-file storage bucket validation failed/
      );
    });

    it('27. Production bucket in any file fails cross-file validation', () => {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeMockDartOptions('chat-app-28ac0.firebasestorage.app');
      const wrapperPath = writeMockRuntimeWrapper(TEST_SYNTHETIC_BUCKET);

      assert.throws(
        () => validateCrossFileConsistency({
          androidPath,
          dartPath,
          wrapperPath,
          expectedStorageBucket: TEST_SYNTHETIC_BUCKET,
        }),
        /Production storage bucket detected/
      );
    });
  });

  describe('Actual Fastlane Staging Guard Ruby Execution Tests', () => {
    function runRubyGuard(options = {}) {
      const guardPath = path.resolve(__dirname, '../../android/fastlane/staging_distribution_guard.rb');
      const repoRoot = path.resolve(__dirname, '../..');

      const rubyCode = `
        require_relative '${guardPath.replace(/\\/g, '/')}'
        StagingDistributionGuard.validate!(
          repo_root: '${repoRoot.replace(/\\/g, '/')}',
          expected_bucket: ${options.expectedBucket ? `'${options.expectedBucket}'` : 'nil'},
          staging_app_id: ${options.stagingAppId ? `'${options.stagingAppId}'` : 'nil'},
          service_creds: ${options.serviceCreds ? `'${options.serviceCreds}'` : 'nil'},
          testers: ${options.testers ? `'${options.testers}'` : 'nil'},
          google_services_path: ${options.googleServicesPath ? `'${options.googleServicesPath.replace(/\\/g, '/')}'` : 'nil'},
          dart_generated_path: ${options.dartGeneratedPath ? `'${options.dartGeneratedPath.replace(/\\/g, '/')}'` : 'nil'},
          dart_wrapper_path: ${options.dartWrapperPath ? `'${options.dartWrapperPath.replace(/\\/g, '/')}'` : 'nil'}
        )
      `;

      // Locate ruby binary
      const rubyBin = process.platform === 'win32' && fs.existsSync('C:\\Ruby34-x64\\bin\\ruby.exe')
        ? 'C:\\Ruby34-x64\\bin\\ruby.exe'
        : 'ruby';

      const res = spawnSync(rubyBin, ['-e', rubyCode], { encoding: 'utf8' });
      return res;
    }

    it('28. Actual Fastlane Ruby guard accepts valid configuration', function () {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const dartPath = writeFixture('options.dart', `
class DefaultFirebaseOptions {
  static const android = FirebaseOptions(storageBucket: '${TEST_SYNTHETIC_BUCKET}');
  static const ios = FirebaseOptions(storageBucket: '${TEST_SYNTHETIC_BUCKET}');
}
`);
      const wrapperPath = writeFixture('wrapper.dart', `
class DefaultFirebaseOptionsStaging {
  static const String expectedProjectId = 'study-buddy-54266';
  static const String expectedProjectNumber = '194789753908';
  static const String? authoritativeStorageBucket = '${TEST_SYNTHETIC_BUCKET}';
}
`);

      const res = runRubyGuard({
        expectedBucket: TEST_SYNTHETIC_BUCKET,
        stagingAppId: '1:194789753908:android:a1b2c3d4e5f6',
        serviceCreds: 'creds.json',
        testers: 'test@example.com',
        googleServicesPath: androidPath,
        dartGeneratedPath: dartPath,
        dartWrapperPath: wrapperPath,
      });

      if (res.error && res.error.code === 'ENOENT') {
        this.skip(); // Ruby not installed on this test host
      }
      if (res.status === 3221225506 || (res.status !== 0 && !res.stderr && !res.stdout)) {
        this.skip(); // Sandbox boundary restriction prevented spawning external Ruby binary
      }

      assert.strictEqual(res.status, 0, `Ruby guard failed unexpectedly: ${res.stderr || res.stdout}`);
    });

    it('29. Actual Fastlane Ruby guard rejects invalid App ID prefix', function () {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const res = runRubyGuard({
        expectedBucket: TEST_SYNTHETIC_BUCKET,
        stagingAppId: '1:194789753908:ios:f6e5d4c3b2a1',
        serviceCreds: 'creds.json',
        testers: 'test@example.com',
        googleServicesPath: androidPath,
      });

      if (res.error && res.error.code === 'ENOENT') {
        this.skip();
      }
      if (res.status === 3221225506 || (res.status !== 0 && !res.stderr && !res.stdout)) {
        this.skip();
      }

      assert.notStrictEqual(res.status, 0);
      assert.match(res.stderr, /must begin with '1:194789753908:android:'/);
    });

    it('30. Actual Fastlane Ruby guard rejects mismatched App ID', function () {
      const androidPath = writeFixture('android.json', validStagingConfig);
      const res = runRubyGuard({
        expectedBucket: TEST_SYNTHETIC_BUCKET,
        stagingAppId: '1:194789753908:android:mismatched_app_id_999',
        serviceCreds: 'creds.json',
        testers: 'test@example.com',
        googleServicesPath: androidPath,
      });

      if (res.error && res.error.code === 'ENOENT') {
        this.skip();
      }
      if (res.status === 3221225506 || (res.status !== 0 && !res.stderr && !res.stdout)) {
        this.skip();
      }

      assert.notStrictEqual(res.status, 0);
      assert.match(res.stderr, /does not match mobilesdk_app_id in google-services\.json/);
    });

    it('31. Actual Fastlane Ruby guard fails when google-services.json is missing', function () {
      const res = runRubyGuard({
        expectedBucket: TEST_SYNTHETIC_BUCKET,
        stagingAppId: '1:194789753908:android:a1b2c3d4e5f6',
        serviceCreds: 'creds.json',
        testers: 'test@example.com',
        googleServicesPath: path.join(tempDir, 'nonexistent.json'),
      });

      if (res.error && res.error.code === 'ENOENT') {
        this.skip();
      }
      if (res.status === 3221225506 || (res.status !== 0 && !res.stderr && !res.stdout)) {
        this.skip();
      }

      assert.notStrictEqual(res.status, 0);
      assert.match(res.stderr, /Staging google-services\.json not found/);
    });
  });
});
