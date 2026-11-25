const fs = require('fs');

function validateGoogleServices(filePath, expectedStorageBucket) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }

  // Mandatory authoritative expectedStorageBucket check
  if (!expectedStorageBucket || typeof expectedStorageBucket !== 'string' || expectedStorageBucket.trim() === '') {
    throw new Error('Mandatory expectedStorageBucket is missing or empty. Staging validation requires an authoritative expected storage bucket.');
  }

  const cleanExpectedBucket = expectedStorageBucket.trim();
  if (cleanExpectedBucket === 'chat-app-28ac0.firebasestorage.app' || cleanExpectedBucket === 'chat-app-28ac0.appspot.com') {
    throw new Error(`Authoritative expectedStorageBucket cannot match Production bucket "${cleanExpectedBucket}"`);
  }

  const raw = fs.readFileSync(filePath, 'utf8');
  const json = JSON.parse(raw);

  const pInfo = json.project_info || {};
  if (pInfo.project_id !== 'study-buddy-54266') {
    throw new Error(`Invalid project_id "${pInfo.project_id}", expected "study-buddy-54266"`);
  }
  if (pInfo.project_number !== '194789753908') {
    throw new Error(`Invalid project_number "${pInfo.project_number}", expected "194789753908"`);
  }

  const bucket = pInfo.storage_bucket;
  if (!bucket || typeof bucket !== 'string' || bucket.trim() === '') {
    throw new Error('Missing or empty storage_bucket in project_info');
  }
  if (bucket === 'chat-app-28ac0.firebasestorage.app' || bucket === 'chat-app-28ac0.appspot.com') {
    throw new Error(`Production storage bucket detected in Staging google-services.json: "${bucket}"`);
  }
  if (bucket !== cleanExpectedBucket) {
    throw new Error(`storage_bucket "${bucket}" does not match authoritative expected bucket "${cleanExpectedBucket}"`);
  }

  const clients = json.client || [];
  const stagingClient = clients.find(c => c.client_info?.android_client_info?.package_name === 'com.example.chat_app.staging');
  if (!stagingClient) {
    throw new Error('No client found with package_name "com.example.chat_app.staging"');
  }

  const appId = stagingClient.client_info?.mobilesdk_app_id || '';
  if (!appId.startsWith('1:194789753908:android:')) {
    throw new Error(`Invalid mobilesdk_app_id "${appId}", expected prefix "1:194789753908:android:"`);
  }

  return {
    projectId: pInfo.project_id,
    projectNumber: pInfo.project_number,
    appId,
    storageBucket: bucket,
  };
}

if (require.main === module) {
  const targetPath = process.argv[2] || 'android/app/src/staging/google-services.json';
  const expectedBucket = process.env.EXPECTED_STAGING_STORAGE_BUCKET || process.argv[3];
  try {
    const res = validateGoogleServices(targetPath, expectedBucket);
    console.log(`Successfully validated Staging google-services.json (Project: ${res.projectId}, App ID: ${res.appId}, Storage Bucket: ${res.storageBucket})`);
  } catch (err) {
    console.error(`FATAL: Staging google-services.json validation failed: ${err.message}`);
    process.exit(1);
  }
}

module.exports = { validateGoogleServices };
