const assert = require('assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { validateGoogleServices } = require('../../tool/validate_staging_google_services');

describe('Staging Secret Contract & Identity Verification Tests', () => {
  let tempDir;

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
      storage_bucket: 'study-buddy-54266.firebasestorage.app'
    },
    client: [
      {
        client_info: {
          mobilesdk_app_id: '1:194789753908:android:a1b2c3d4e5f6',
          android_client_info: {
            package_name: 'com.example.chat_app.staging'
          }
        }
      }
    ]
  };

  it('1. Correct Staging google-services.json is accepted', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    const result = validateGoogleServices(fixturePath);
    assert.strictEqual(result.projectId, 'study-buddy-54266');
    assert.strictEqual(result.projectNumber, '194789753908');
    assert.strictEqual(result.appId, '1:194789753908:android:a1b2c3d4e5f6');
    assert.strictEqual(result.storageBucket, 'study-buddy-54266.firebasestorage.app');
  });

  it('2. Production google-services.json is rejected', () => {
    const prodConfig = {
      project_info: {
        project_number: '639830188590',
        project_id: 'chat-app-28ac0',
        storage_bucket: 'chat-app-28ac0.firebasestorage.app'
      },
      client: [
        {
          client_info: {
            mobilesdk_app_id: '1:639830188590:android:4a3b1c669d60ee593235bf',
            android_client_info: {
              package_name: 'com.example.chat_app'
            }
          }
        }
      ]
    };
    const fixturePath = writeFixture('prod.json', prodConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath),
      /Invalid project_id "chat-app-28ac0", expected "study-buddy-54266"/
    );
  });

  it('3. Wrong Android package is rejected', () => {
    const wrongPackageConfig = JSON.parse(JSON.stringify(validStagingConfig));
    wrongPackageConfig.client[0].client_info.android_client_info.package_name = 'com.example.chat_app.dev';
    const fixturePath = writeFixture('wrong-package.json', wrongPackageConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath),
      /No client found with package_name "com.example.chat_app.staging"/
    );
  });

  it('4. Wrong project number is rejected', () => {
    const wrongNumberConfig = JSON.parse(JSON.stringify(validStagingConfig));
    wrongNumberConfig.project_info.project_number = '999999999999';
    const fixturePath = writeFixture('wrong-number.json', wrongNumberConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath),
      /Invalid project_number "999999999999", expected "194789753908"/
    );
  });

  it('5. iOS App ID is rejected for Android distribution', () => {
    const iosAppIdConfig = JSON.parse(JSON.stringify(validStagingConfig));
    iosAppIdConfig.client[0].client_info.mobilesdk_app_id = '1:194789753908:ios:f6e5d4c3b2a1';
    const fixturePath = writeFixture('ios-app-id.json', iosAppIdConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath),
      /Invalid mobilesdk_app_id "1:194789753908:ios:f6e5d4c3b2a1", expected prefix "1:194789753908:android:"/
    );
  });

  it('6. Missing file throws descriptive error', () => {
    const nonExistentPath = path.join(tempDir, 'does-not-exist.json');
    assert.throws(
      () => validateGoogleServices(nonExistentPath),
      /File not found/
    );
  });

  it('7. Malformed JSON file is rejected', () => {
    const malformedPath = writeFixture('malformed.json', '{ invalid json ');
    assert.throws(
      () => validateGoogleServices(malformedPath),
      /Unexpected token|JSON/
    );
  });

  it('8. Missing or empty storage_bucket is rejected', () => {
    const emptyBucketConfig = JSON.parse(JSON.stringify(validStagingConfig));
    delete emptyBucketConfig.project_info.storage_bucket;
    const fixturePath1 = writeFixture('empty-bucket.json', emptyBucketConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath1),
      /Missing or empty storage_bucket/
    );

    emptyBucketConfig.project_info.storage_bucket = '   ';
    const fixturePath2 = writeFixture('whitespace-bucket.json', emptyBucketConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath2),
      /Missing or empty storage_bucket/
    );
  });

  it('9. Production storage_bucket in Staging config is rejected', () => {
    const prodBucketConfig = JSON.parse(JSON.stringify(validStagingConfig));
    prodBucketConfig.project_info.storage_bucket = 'chat-app-28ac0.firebasestorage.app';
    const fixturePath = writeFixture('prod-bucket.json', prodBucketConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath),
      /Production storage bucket detected/
    );
  });

  it('10. Mismatched expected storage_bucket is rejected', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    assert.throws(
      () => validateGoogleServices(fixturePath, 'expected-different-bucket.appspot.com'),
      /does not match authoritative expected bucket/
    );
  });

  it('11. Matching expected storage_bucket succeeds', () => {
    const fixturePath = writeFixture('valid-staging.json', validStagingConfig);
    const res = validateGoogleServices(fixturePath, 'study-buddy-54266.firebasestorage.app');
    assert.strictEqual(res.storageBucket, 'study-buddy-54266.firebasestorage.app');
  });

  describe('Fastlane App ID Guard Simulation Tests', () => {
    function simulateFastlaneGuard(stagingAppId, googleServicesPath) {
      if (!stagingAppId || stagingAppId.trim() === '') {
        throw new Error('Missing required environment variable STAGING_FIREBASE_APP_ID');
      }
      if (!stagingAppId.startsWith('1:194789753908:android:')) {
        throw new Error(`STAGING_FIREBASE_APP_ID '${stagingAppId}' is invalid: must begin with '1:194789753908:android:'`);
      }
      if (!fs.existsSync(googleServicesPath)) {
        throw new Error(`Staging google-services.json not found at ${googleServicesPath}`);
      }
      const gsContent = JSON.parse(fs.readFileSync(googleServicesPath, 'utf8'));
      const clients = gsContent.client || [];
      const stagingClient = clients.find(c => c.client_info?.android_client_info?.package_name === 'com.example.chat_app.staging');
      const gsAppId = stagingClient?.client_info?.mobilesdk_app_id;
      if (!gsAppId) {
        throw new Error('No matching client with package com.example.chat_app.staging found');
      }
      if (gsAppId !== stagingAppId) {
        throw new Error(`STAGING_FIREBASE_APP_ID ('${stagingAppId}') does not match mobilesdk_app_id in google-services.json ('${gsAppId}')`);
      }
      return true;
    }

    it('12. Fastlane accepts matching Android App ID with google-services.json', () => {
      const gsPath = writeFixture('valid-gs.json', validStagingConfig);
      assert.strictEqual(
        simulateFastlaneGuard('1:194789753908:android:a1b2c3d4e5f6', gsPath),
        true
      );
    });

    it('13. Fastlane rejects iOS App ID for Android distribution', () => {
      const gsPath = writeFixture('valid-gs.json', validStagingConfig);
      assert.throws(
        () => simulateFastlaneGuard('1:194789753908:ios:f6e5d4c3b2a1', gsPath),
        /must begin with '1:194789753908:android:'/
      );
    });

    it('14. Fastlane rejects mismatched App ID between ENV and google-services.json', () => {
      const gsPath = writeFixture('valid-gs.json', validStagingConfig);
      assert.throws(
        () => simulateFastlaneGuard('1:194789753908:android:different_app_id_999', gsPath),
        /does not match mobilesdk_app_id in google-services.json/
      );
    });

    it('15. Fastlane fails if Staging google-services.json is missing', () => {
      assert.throws(
        () => simulateFastlaneGuard('1:194789753908:android:a1b2c3d4e5f6', '/nonexistent/path/google-services.json'),
        /not found at/
      );
    });
  });
});
