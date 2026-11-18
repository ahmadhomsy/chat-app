import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  addDoc,
  serverTimestamp,
} from 'firebase/firestore';

const PROJECT_ID = 'chat-app-28ac0';

describe('Firebase Security Rules Independent Verification Tests', () => {
  let testEnv: RulesTestEnvironment;

  before(async () => {
    const firestoreRulesPath = path.resolve(process.cwd(), '../firestore.rules');
    const storageRulesPath = path.resolve(process.cwd(), '../storage.rules');
    const databaseRulesPath = path.resolve(process.cwd(), '../database.rules.json');

    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync(firestoreRulesPath, 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
      storage: {
        rules: fs.readFileSync(storageRulesPath, 'utf8'),
        host: '127.0.0.1',
        port: 9199,
      },
      database: {
        rules: fs.readFileSync(databaseRulesPath, 'utf8'),
        host: '127.0.0.1',
        port: 9000,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.clearDatabase();
    await testEnv.clearStorage();
  });

  // 1. Unauthenticated users cannot access protected resources
  it('1. Unauthenticated users cannot access protected resources', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    const unauthedRtdb = testEnv.unauthenticatedContext().database();
    const unauthedStorage = testEnv.unauthenticatedContext().storage();

    // Firestore unauthenticated reads & writes
    await assertFails(getDoc(doc(unauthedDb, 'users', 'alice')));
    await assertFails(getDoc(doc(unauthedDb, 'conversations', 'c1')));
    await assertFails(
      addDoc(collection(unauthedDb, 'conversations', 'c1', 'messages'), {
        senderId: 'alice',
        text: 'hello',
      })
    );

    // RTDB unauthenticated read & write
    await assertFails(unauthedRtdb.ref('status/alice').once('value'));
    await assertFails(unauthedRtdb.ref('status/alice/connections/c1').set(true));

    // Storage unauthenticated read & write
    const storageRef = unauthedStorage.ref('conversations/c1/photo.jpg');
    await assertFails(storageRef.getDownloadURL());
  });

  // 2. Users cannot read private FCM tokens belonging to other users
  it('2. Users cannot read private FCM tokens belonging to other users', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Alice can store and read her own FCM token
    await assertSucceeds(
      setDoc(doc(aliceDb, 'users', 'alice', 'fcmTokens', 'tok_alice_1'), {
        token: 'fcm_token_alice_123',
        createdAt: serverTimestamp(),
      })
    );
    await assertSucceeds(getDoc(doc(aliceDb, 'users', 'alice', 'fcmTokens', 'tok_alice_1')));

    // Bob cannot read Alice's FCM token
    await assertFails(getDoc(doc(bobDb, 'users', 'alice', 'fcmTokens', 'tok_alice_1')));

    // Bob cannot inject a fake token into Alice's tokens
    await assertFails(
      setDoc(doc(bobDb, 'users', 'alice', 'fcmTokens', 'tok_fake'), {
        token: 'hacked_token',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 3. Non-participants cannot read or write direct conversations
  it('3. Non-participants cannot read or write direct conversations', async () => {
    // Seed direct conversation between Alice and Bob
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const charlieDb = testEnv.authenticatedContext('charlie').firestore();

    // Alice (participant) can read
    await assertSucceeds(getDoc(doc(aliceDb, 'conversations', 'conv_alice_bob')));

    // Charlie (non-participant) CANNOT read
    await assertFails(getDoc(doc(charlieDb, 'conversations', 'conv_alice_bob')));

    // Charlie (non-participant) CANNOT send message
    await assertFails(
      setDoc(doc(charlieDb, 'conversations', 'conv_alice_bob', 'messages', 'msg_eavesdrop'), {
        senderId: 'charlie',
        senderName: 'Charlie',
        text: 'Sneaking in',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 4. Regular group members cannot modify administrator-controlled metadata
  it('4. Regular group members cannot modify administrator-controlled metadata', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_dev'), {
        type: 'group',
        groupName: 'Dev Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'], // Alice is admin, Bob is regular member
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Bob cannot change group name
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_dev'), {
        groupName: 'Hacked Team Name',
      })
    );

    // Bob cannot change participant list
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_dev'), {
        participantIds: ['alice', 'bob', 'charlie'],
      })
    );

    // Alice (admin) can change group name
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'conversations', 'group_dev'), {
        groupName: 'Core Engineering Team',
      })
    );
  });

  // 5. Regular members cannot promote themselves to administrators
  it('5. Regular members cannot promote themselves to administrators', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_ops'), {
        type: 'group',
        groupName: 'Ops Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob attempts to elevate his privileges by adding himself to adminIds
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_ops'), {
        adminIds: ['alice', 'bob'],
      })
    );
  });

  // 6. Users cannot impersonate another message sender
  it('6. Users cannot impersonate another message sender', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_chat'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice sends message as Alice -> allowed
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'conv_chat', 'messages', 'msg_alice_1'), {
        senderId: 'alice',
        senderName: 'Alice',
        text: 'Hey Bob!',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );

    // Alice sends message claiming senderId is 'bob' -> rejected
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'conv_chat', 'messages', 'msg_spoofed'), {
        senderId: 'bob',
        senderName: 'Bob',
        text: 'I agree with everything Alice said',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 7. Users cannot modify another participant\'s read receipts
  it('7. Users cannot modify another participant read receipts', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_receipts'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        lastReadAtByUser: {
          alice: 1000,
          bob: 1000,
        },
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice can update her own read receipt
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'conversations', 'conv_receipts'), {
        'lastReadAtByUser.alice': 2000,
      })
    );

    // Alice CANNOT alter Bob's read receipt
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'conv_receipts'), {
        'lastReadAtByUser.bob': 9999,
      })
    );
  });

  // 8. Users cannot access another conversation\'s private attachments
  it('8. Users cannot access another conversation private attachments in Storage', async () => {
    // Seed conversation in Firestore with Alice and Bob
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_secret'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const charlieStorage = testEnv.authenticatedContext('charlie').storage();
    const aliceStorage = testEnv.authenticatedContext('alice').storage();

    const charlieFileRef = charlieStorage.ref('conversations/conv_secret/doc.pdf');
    const aliceFileRef = aliceStorage.ref('conversations/conv_secret/doc.pdf');

    // Charlie (non-participant) cannot download or upload
    await assertFails(charlieFileRef.getDownloadURL());
    await assertFails(
      charlieFileRef.put(Buffer.from('secret contract'), {
        contentType: 'application/pdf',
      })
    );

    // Alice (participant) can upload valid attachment
    await assertSucceeds(
      aliceFileRef.put(Buffer.from('contract content'), {
        contentType: 'application/pdf',
      })
    );
  });

  // 9. Users cannot modify another user\'s presence records
  it('9. Users cannot modify another user presence records in Realtime Database', async () => {
    const aliceRtdb = testEnv.authenticatedContext('alice').database();
    const bobRtdb = testEnv.authenticatedContext('bob').database();

    // Alice can set her own device connection in RTDB
    await assertSucceeds(aliceRtdb.ref('status/alice/connections/phone_1').set(true));

    // Alice can set her own lastSeen
    await assertSucceeds(aliceRtdb.ref('status/alice/lastSeen').set(1710000000));

    // Bob CANNOT modify Alice's presence record
    await assertFails(bobRtdb.ref('status/alice/connections/phone_1').set(false));
    await assertFails(bobRtdb.ref('status/alice/lastSeen').set(12345));

    // Bob can set his own
    await assertSucceeds(bobRtdb.ref('status/bob/connections/tablet_1').set(true));
  });
});
