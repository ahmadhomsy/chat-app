const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

const PROD_BUCKETS = [
  'chat-app-28ac0.firebasestorage.app',
  'chat-app-28ac0.appspot.com',
];

function resolveRepoPath(filePath) {
  if (!filePath) return filePath;
  if (path.isAbsolute(filePath)) return filePath;
  return path.resolve(REPO_ROOT, filePath);
}

function validateGoogleServices(filePath, expectedStorageBucket) {
  const resolvedPath = resolveRepoPath(filePath);

  if (!fs.existsSync(resolvedPath)) {
    throw new Error(`File not found: ${resolvedPath}`);
  }

  // Mandatory authoritative expectedStorageBucket check
  if (!expectedStorageBucket || typeof expectedStorageBucket !== 'string' || expectedStorageBucket.trim() === '') {
    throw new Error('Mandatory expectedStorageBucket is missing or empty. Staging validation requires an authoritative expected storage bucket.');
  }

  const cleanExpectedBucket = expectedStorageBucket.trim();
  if (PROD_BUCKETS.includes(cleanExpectedBucket)) {
    throw new Error(`Authoritative expectedStorageBucket cannot match Production bucket "${cleanExpectedBucket}"`);
  }

  const raw = fs.readFileSync(resolvedPath, 'utf8');
  let json;
  try {
    json = JSON.parse(raw);
  } catch (e) {
    throw new Error(`Malformed JSON in google-services.json: ${e.message}`);
  }

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
  if (PROD_BUCKETS.includes(bucket)) {
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
    filePath: resolvedPath,
  };
}

if (require.main === module) {
  const targetPath = process.argv[2] || 'android/app/src/staging/google-services.json';
  const expectedBucket = process.env.EXPECTED_STAGING_STORAGE_BUCKET || process.env.STAGING_STORAGE_BUCKET || process.argv[3];
  try {
    const res = validateGoogleServices(targetPath, expectedBucket);
    console.log(`Successfully validated Staging google-services.json (Project: ${res.projectId}, App ID: ${res.appId}, Storage Bucket: ${res.storageBucket})`);
  } catch (err) {
    console.error(`FATAL: Staging google-services.json validation failed: ${err.message}`);
    process.exit(1);
  }
}

module.exports = {
  validateGoogleServices,
  resolveRepoPath,
};
