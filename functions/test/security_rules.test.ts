import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
  RulesTestEnvironment,
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

describe('Firestore & Storage Security Rules Audit Tests', () => {
  let testEnv: RulesTestEnvironment;

  before(async () => {
    const firestoreRulesPath = path.resolve(__dirname, '../../firestore.rules');
    const storageRulesPath = path.resolve(__dirname, '../../storage.rules');

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
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  // CASE 1: Unauthenticated access is rejected
  it('1. Unauthenticated access is rejected across all resources', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();

    // Trying to read a user profile
    await assertFails(getDoc(doc(unauthedDb, 'users', 'alice')));

    // Trying to read a conversation
    await assertFails(getDoc(doc(unauthedDb, 'conversations', 'c1')));

    // Trying to write a message
    await assertFails(
      addDoc(collection(unauthedDb, 'conversations', 'c1', 'messages'), {
        senderId: 'alice',
        text: 'hello',
      })
    );
  });

  // CASE 2: Conversation participant can read the conversation
  it('2. A conversation participant can read the conversation', async () => {
    // Setup conversation with admin context
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_123'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(getDoc(doc(aliceDb, 'conversations', 'conv_123')));
  });

  // CASE 3: Non-participant cannot read the conversation
  it('3. A non-participant cannot read the conversation', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_private'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const charlieDb = testEnv.authenticatedContext('charlie').firestore();
    await assertFails(getDoc(doc(charlieDb, 'conversations', 'conv_private')));
  });

  // CASE 4: A participant can send an authorized message
  it('4. A participant can send an authorized message', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_chat'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'conv_chat', 'messages', 'msg_1'), {
        senderId: 'alice',
        senderName: 'Alice',
        text: 'Hello Bob!',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );
  });

  // CASE 5: Impersonation: User cannot send a message impersonating another user
  it('5. A user cannot send a message impersonating another user', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'conv_chat'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    // Alice authenticates but attempts to send message with senderId: 'bob'
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'conv_chat', 'messages', 'msg_fake'), {
        senderId: 'bob', // Impersonation!
        senderName: 'Bob',
        text: 'I am bob',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );
  });

  // CASE 6: Unauthorized group membership changes are rejected
  it('6. Unauthorized group membership changes are rejected', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_1'), {
        type: 'group',
        groupName: 'Engineers',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'], // Alice is admin, Bob is ordinary member
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    // Bob (non-admin) tries to change adminIds or add charlie
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_1'), {
        adminIds: ['alice', 'bob'], // Promoting himself
      })
    );

    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_1'), {
        participantIds: ['alice', 'bob', 'charlie'], // Adding charlie without admin permission
      })
    );
  });

  // CASE 7: Users cannot modify another user's protected profile fields
  it("7. Users cannot modify another user's profile or protected fields", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', 'alice'), {
        id: 'alice',
        name: 'Alice',
        email: 'alice@example.com',
        provider: 'password',
        createdAt: serverTimestamp(),
        isOnline: true,
      });
    });

    // Bob tries to update Alice's profile
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    await assertFails(
      updateDoc(doc(bobDb, 'users', 'alice'), {
        name: 'Hacked by Bob',
      })
    );

    // Alice tries to modify her own protected 'email' or 'provider' field
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(aliceDb, 'users', 'alice'), {
        email: 'attacker@evil.com',
      })
    );

    // Alice can update her own name or photoUrl
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'users', 'alice'), {
        name: 'Alice Smith',
      })
    );
  });

  // CASE 8: FCM Token isolation in subcollection
  it('8. Users cannot read or write another user private FCM tokens', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Alice can write and read her own token
    await assertSucceeds(
      setDoc(doc(aliceDb, 'users', 'alice', 'fcmTokens', 'token_123'), {
        token: 'token_123',
        createdAt: serverTimestamp(),
      })
    );
    await assertSucceeds(getDoc(doc(aliceDb, 'users', 'alice', 'fcmTokens', 'token_123')));

    // Bob cannot read or write Alice's FCM token
    await assertFails(getDoc(doc(bobDb, 'users', 'alice', 'fcmTokens', 'token_123')));
    await assertFails(
      setDoc(doc(bobDb, 'users', 'alice', 'fcmTokens', 'token_fake'), {
        token: 'token_fake',
        createdAt: serverTimestamp(),
      })
    );
  });
});
