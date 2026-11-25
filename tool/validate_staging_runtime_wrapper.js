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

function extractRuntimeWrapperBucket(content) {
  const match = content.match(/static\s+const\s+String\?\s+authoritativeStorageBucket\s*=\s*(null|['"][^'"]*['"])\s*;/);
  if (!match) {
    throw new Error('Could not find "static const String? authoritativeStorageBucket" declaration in Runtime Wrapper');
  }

  const rawValue = match[1].trim();
  if (rawValue === 'null') {
    throw new Error('authoritativeStorageBucket in Runtime Wrapper is null. Staging remains unconfigured and cannot be distributed.');
  }

  const bucket = rawValue.slice(1, -1).trim();
  if (!bucket) {
    throw new Error('authoritativeStorageBucket in Runtime Wrapper is empty or whitespace-only.');
  }

  return bucket;
}

function validateRuntimeWrapper(options = {}) {
  let wrapperPath;
  let expectedBucket;

  if (typeof options === 'string') {
    wrapperPath = options;
    expectedBucket = arguments[1];
  } else {
    wrapperPath = options.wrapperPath;
    expectedBucket = options.expectedStorageBucket;
  }

  wrapperPath = resolveRepoPath(wrapperPath || 'lib/firebase_options_staging.dart');
  expectedBucket = expectedBucket || process.env.EXPECTED_STAGING_STORAGE_BUCKET || process.env.STAGING_STORAGE_BUCKET || process.argv[2];

  if (!expectedBucket || typeof expectedBucket !== 'string' || expectedBucket.trim() === '') {
    throw new Error('Mandatory expectedStorageBucket is missing or empty for Runtime Wrapper validation.');
  }

  const cleanExpectedBucket = expectedBucket.trim();
  if (PROD_BUCKETS.includes(cleanExpectedBucket)) {
    throw new Error(`Authoritative expected storage bucket cannot be a Production bucket "${cleanExpectedBucket}"`);
  }

  if (!fs.existsSync(wrapperPath)) {
    throw new Error(`Runtime Wrapper file not found at ${wrapperPath}`);
  }

  const content = fs.readFileSync(wrapperPath, 'utf8');
  const bucket = extractRuntimeWrapperBucket(content);

  if (PROD_BUCKETS.includes(bucket)) {
    throw new Error(`Production storage bucket detected in Runtime Wrapper: "${bucket}"`);
  }

  if (bucket !== cleanExpectedBucket) {
    throw new Error(`authoritativeStorageBucket "${bucket}" in Runtime Wrapper does not match expected bucket "${cleanExpectedBucket}"`);
  }

  return {
    verifiedBucket: cleanExpectedBucket,
    wrapperPath,
  };
}

if (require.main === module) {
  const targetPath = process.argv[2] && process.argv[2].endsWith('.dart') ? process.argv[2] : undefined;
  const expected = targetPath ? process.argv[3] : process.argv[2];
  try {
    const res = validateRuntimeWrapper({ wrapperPath: targetPath, expectedStorageBucket: expected });
    console.log(`Runtime Wrapper verification SUCCESS: authoritativeStorageBucket matches verified bucket "${res.verifiedBucket}" (${res.wrapperPath})`);
  } catch (err) {
    console.error(`FATAL: Runtime Wrapper validation failed: ${err.message}`);
    process.exit(1);
  }
}

module.exports = {
  validateRuntimeWrapper,
  extractRuntimeWrapperBucket,
};
