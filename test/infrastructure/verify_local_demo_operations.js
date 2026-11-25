const path = require('path');
const admin = require(path.resolve(__dirname, '../../functions/node_modules/firebase-admin'));
const assert = require('assert');

process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_DATABASE_EMULATOR_HOST = '127.0.0.1:9000';
process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';

async function runVerification() {
  console.log('[Verification] Initializing Firebase Admin for demo project: demo-chatup');
  const app = admin.initializeApp({
    projectId: 'demo-chatup',
  }, 'demo-verification-app');

  const auth = admin.auth(app);
  const firestore = admin.firestore(app);

  try {
    // 1. Local Auth Operation
    console.log('[Verification] Testing local Auth operation in Emulator...');
    const testEmail = `demo-user-${Date.now()}@example.com`;
    const userRecord = await auth.createUser({
      email: testEmail,
      password: 'DemoPassword123!',
      displayName: 'Local Demo User',
    });
    console.log(`[Verification] Successfully created local Auth user: ${userRecord.uid} (${userRecord.email})`);

    const fetchedUser = await auth.getUser(userRecord.uid);
    assert.strictEqual(fetchedUser.email, testEmail);
    console.log('[Verification] Local Auth verification: PASS');

    // 2. Local Firestore Operation
    console.log('[Verification] Testing local Firestore operation in Emulator...');
    const docRef = firestore.collection('demo_verification').doc(userRecord.uid);
    await docRef.set({
      uid: userRecord.uid,
      displayName: 'Local Demo User',
      verifiedLocally: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      projectId: 'demo-chatup',
    });
    console.log('[Verification] Successfully wrote document to Firestore emulator');

    const snap = await docRef.get();
    assert.ok(snap.exists, 'Document must exist in Firestore emulator');
    const data = snap.data();
    assert.strictEqual(data.projectId, 'demo-chatup');
    assert.strictEqual(data.verifiedLocally, true);
    console.log('[Verification] Local Firestore verification: PASS');

    // 3. Clean up
    await docRef.delete();
    await auth.deleteUser(userRecord.uid);
    console.log('[Verification] Local cleanup complete: PASS');

    console.log('[Verification] All local emulator operations succeeded with ZERO cloud resource usage / zero billing impact.');
  } finally {
    await app.delete();
  }
}

runVerification().catch(err => {
  console.error('[Verification] FATAL ERROR:', err);
  process.exit(1);
});
