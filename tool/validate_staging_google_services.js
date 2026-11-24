const fs = require('fs');

function validateGoogleServices(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
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

  const clients = json.client || [];
  const stagingClient = clients.find(c => c.client_info?.android_client_info?.package_name === 'com.example.chat_app.staging');
  if (!stagingClient) {
    throw new Error('No client found with package_name "com.example.chat_app.staging"');
  }

  const appId = stagingClient.client_info?.mobilesdk_app_id || '';
  if (!appId.startsWith('1:194789753908:android:')) {
    throw new Error(`Invalid mobilesdk_app_id "${appId}", expected prefix "1:194789753908:android:"`);
  }

  return { projectId: pInfo.project_id, projectNumber: pInfo.project_number, appId };
}

if (require.main === module) {
  const targetPath = process.argv[2] || 'android/app/src/staging/google-services.json';
  try {
    const res = validateGoogleServices(targetPath);
    console.log(`Successfully validated Staging google-services.json (Project: ${res.projectId}, App ID: ${res.appId})`);
  } catch (err) {
    console.error(`FATAL: Staging google-services.json validation failed: ${err.message}`);
    process.exit(1);
  }
}

module.exports = { validateGoogleServices };
