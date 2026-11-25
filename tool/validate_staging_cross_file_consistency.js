const fs = require('fs');
const path = require('path');

function extractDartBucket(content) {
  const matches = [...content.matchAll(/storageBucket:\s*['"]([^'"]+)['"]/g)];
  if (matches.length === 0) {
    throw new Error('No storageBucket declarations found in Dart generated options file');
  }
  const buckets = matches.map(m => m[1]);
  const unique = [...new Set(buckets)];
  if (unique.length > 1) {
    throw new Error(`Inconsistent storageBucket values within Dart options: ${unique.join(', ')}`);
  }
  return unique[0];
}

function extractPlistBucket(content) {
  const match = content.match(/<key>STORAGE_BUCKET<\/key>\s*<string>([^<]+)<\/string>/);
  if (!match) {
    throw new Error('No STORAGE_BUCKET key found in iOS plist file');
  }
  return match[1].trim();
}

function validateCrossFileConsistency(options = {}) {
  const expectedBucket = options.expectedStorageBucket || process.env.EXPECTED_STAGING_STORAGE_BUCKET || process.argv[2];

  if (!expectedBucket || typeof expectedBucket !== 'string' || expectedBucket.trim() === '') {
    throw new Error('Mandatory expectedStorageBucket is missing or empty for cross-file consistency check.');
  }

  const cleanExpectedBucket = expectedBucket.trim();
  if (cleanExpectedBucket === 'chat-app-28ac0.firebasestorage.app' || cleanExpectedBucket === 'chat-app-28ac0.appspot.com') {
    throw new Error(`Authoritative expected storage bucket cannot be a Production bucket "${cleanExpectedBucket}"`);
  }

  const androidPath = options.androidPath || 'android/app/src/staging/google-services.json';
  const dartPath = options.dartPath || 'lib/firebase_options_staging.generated.dart';
  const iosPath = options.iosPath || (
    fs.existsSync('ios/Runner/Firebase/Staging/GoogleService-Info.plist')
      ? 'ios/Runner/Firebase/Staging/GoogleService-Info.plist'
      : (fs.existsSync('ios/Firebase/GoogleService-Info-staging.plist') ? 'ios/Firebase/GoogleService-Info-staging.plist' : null)
  );

  const discoveredBuckets = {};

  // 1. Android google-services.json
  if (!fs.existsSync(androidPath)) {
    throw new Error(`Android staging configuration file not found at ${androidPath}`);
  }
  const androidJson = JSON.parse(fs.readFileSync(androidPath, 'utf8'));
  const androidBucket = androidJson.project_info?.storage_bucket;
  if (!androidBucket || androidBucket.trim() === '') {
    throw new Error(`Missing or empty storage_bucket in ${androidPath}`);
  }
  discoveredBuckets.android = androidBucket.trim();

  // 2. Dart generated options
  if (!fs.existsSync(dartPath)) {
    throw new Error(`Dart staging options file not found at ${dartPath}`);
  }
  const dartContent = fs.readFileSync(dartPath, 'utf8');
  discoveredBuckets.dart = extractDartBucket(dartContent);

  // 3. iOS plist (if supplied)
  if (iosPath && fs.existsSync(iosPath)) {
    const iosContent = fs.readFileSync(iosPath, 'utf8');
    discoveredBuckets.ios = extractPlistBucket(iosContent);
  }

  // Cross-file consistency assertions
  const errors = [];
  for (const [source, bucket] of Object.entries(discoveredBuckets)) {
    if (bucket === 'chat-app-28ac0.firebasestorage.app' || bucket === 'chat-app-28ac0.appspot.com') {
      errors.push(`[${source}] Production storage bucket detected: "${bucket}"`);
    }
    if (bucket !== cleanExpectedBucket) {
      errors.push(`[${source}] Declared bucket "${bucket}" does not match authoritative expected bucket "${cleanExpectedBucket}"`);
    }
  }

  const uniqueBuckets = [...new Set(Object.values(discoveredBuckets))];
  if (uniqueBuckets.length > 1) {
    errors.push(`Cross-file mismatch between environments: ${JSON.stringify(discoveredBuckets)}`);
  }

  if (errors.length > 0) {
    throw new Error(`Cross-file storage bucket validation failed:\n  - ${errors.join('\n  - ')}`);
  }

  return {
    verifiedBucket: cleanExpectedBucket,
    verifiedSources: discoveredBuckets,
  };
}

if (require.main === module) {
  try {
    const res = validateCrossFileConsistency();
    console.log(`Cross-file verification SUCCESS: All staging files consistently declare storage bucket "${res.verifiedBucket}" (Sources: ${Object.keys(res.verifiedSources).join(', ')})`);
  } catch (err) {
    console.error(`FATAL: ${err.message}`);
    process.exit(1);
  }
}

module.exports = { validateCrossFileConsistency };
