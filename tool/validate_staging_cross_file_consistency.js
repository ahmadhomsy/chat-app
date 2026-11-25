const fs = require('fs');
const path = require('path');
const { extractRuntimeWrapperBucket } = require('./validate_staging_runtime_wrapper');

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
  const expectedBucket = options.expectedStorageBucket ||
    process.env.EXPECTED_STAGING_STORAGE_BUCKET ||
    process.env.STAGING_STORAGE_BUCKET ||
    process.argv[2];

  if (!expectedBucket || typeof expectedBucket !== 'string' || expectedBucket.trim() === '') {
    throw new Error('Mandatory expectedStorageBucket is missing or empty for cross-file consistency check.');
  }

  const cleanExpectedBucket = expectedBucket.trim();
  if (PROD_BUCKETS.includes(cleanExpectedBucket)) {
    throw new Error(`Authoritative expected storage bucket cannot be a Production bucket "${cleanExpectedBucket}"`);
  }

  const androidPath = resolveRepoPath(
    options.androidPath || process.env.STAGING_ANDROID_PATH || 'android/app/src/staging/google-services.json'
  );
  const dartPath = resolveRepoPath(
    options.dartPath || options.dartGeneratedPath || process.env.STAGING_DART_GENERATED_PATH || 'lib/firebase_options_staging.generated.dart'
  );
  const wrapperPath = resolveRepoPath(
    options.wrapperPath || options.dartWrapperPath || process.env.STAGING_DART_WRAPPER_PATH || 'lib/firebase_options_staging.dart'
  );

  // iOS plist path: only evaluated when explicitly supplied
  let rawIosPath = options.iosPath;
  if (rawIosPath === undefined) {
    rawIosPath = process.env.STAGING_IOS_PLIST_PATH || (process.argv[3] && !process.argv[3].startsWith('-') ? process.argv[3] : null);
  }

  const discoveredBuckets = {};

  // 1. Android google-services.json
  if (!fs.existsSync(androidPath)) {
    throw new Error(`Android staging configuration file not found at ${androidPath}`);
  }
  let androidJson;
  try {
    androidJson = JSON.parse(fs.readFileSync(androidPath, 'utf8'));
  } catch (e) {
    throw new Error(`Malformed JSON in Android configuration at ${androidPath}: ${e.message}`);
  }
  const androidBucket = androidJson.project_info?.storage_bucket;
  if (!androidBucket || typeof androidBucket !== 'string' || androidBucket.trim() === '') {
    throw new Error(`Missing or empty storage_bucket in ${androidPath}`);
  }
  discoveredBuckets.android = androidBucket.trim();

  // 2. Dart generated options
  if (!fs.existsSync(dartPath)) {
    throw new Error(`Dart staging generated options file not found at ${dartPath}`);
  }
  const dartContent = fs.readFileSync(dartPath, 'utf8');
  discoveredBuckets.dart_generated = extractDartBucket(dartContent);

  // 3. Dart Runtime Wrapper options (if checkWrapper is not disabled)
  if (options.checkWrapper !== false) {
    if (!fs.existsSync(wrapperPath)) {
      throw new Error(`Dart staging Runtime Wrapper file not found at ${wrapperPath}`);
    }
    const wrapperContent = fs.readFileSync(wrapperPath, 'utf8');
    discoveredBuckets.dart_wrapper = extractRuntimeWrapperBucket(wrapperContent);
  }

  // 4. iOS plist (checked ONLY when explicitly supplied)
  if (rawIosPath !== null && rawIosPath !== undefined && rawIosPath.trim() !== '') {
    const iosPath = resolveRepoPath(rawIosPath.trim());
    if (!fs.existsSync(iosPath)) {
      throw new Error(`Explicitly supplied iOS plist file not found at ${iosPath}`);
    }
    const iosContent = fs.readFileSync(iosPath, 'utf8');
    discoveredBuckets.ios = extractPlistBucket(iosContent);
  }

  // Cross-file consistency assertions
  const errors = [];
  for (const [source, bucket] of Object.entries(discoveredBuckets)) {
    if (PROD_BUCKETS.includes(bucket)) {
      errors.push(`[${source}] Production storage bucket detected: "${bucket}"`);
    }
    if (bucket !== cleanExpectedBucket) {
      errors.push(`[${source}] Declared bucket "${bucket}" does not match authoritative expected bucket "${cleanExpectedBucket}"`);
    }
  }

  const uniqueBuckets = [...new Set(Object.values(discoveredBuckets))];
  if (uniqueBuckets.length > 1) {
    errors.push(`Cross-file mismatch between configuration sources: ${JSON.stringify(discoveredBuckets)}`);
  }

  if (errors.length > 0) {
    throw new Error(`Cross-file storage bucket validation failed:\n  - ${errors.join('\n  - ')}`);
  }

  const isIosIncluded = Boolean(discoveredBuckets.ios);
  const targetCount = isIosIncluded ? 3 : 2;
  const modeDescription = isIosIncluded
    ? '3-target (Android + Dart + iOS)'
    : '2-target (Android + Dart)';

  return {
    verifiedBucket: cleanExpectedBucket,
    targetCount,
    mode: modeDescription,
    verifiedSources: discoveredBuckets,
    verifiedFiles: Object.keys(discoveredBuckets),
  };
}

if (require.main === module) {
  try {
    const res = validateCrossFileConsistency();
    console.log(`Cross-file verification SUCCESS [${res.mode}]: All staging configuration sources consistently declare storage bucket "${res.verifiedBucket}" (Sources: ${Object.keys(res.verifiedSources).join(', ')})`);
  } catch (err) {
    console.error(`FATAL: Cross-file consistency validation failed: ${err.message}`);
    process.exit(1);
  }
}

module.exports = {
  validateCrossFileConsistency,
  extractDartBucket,
  extractPlistBucket,
  resolveRepoPath,
};
