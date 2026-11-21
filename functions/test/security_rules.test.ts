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
  getDocs,
  setDoc,
  updateDoc,
  collection,
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

  // 1. An authenticated user attempting to list all private user profiles
  it('1. An authenticated user attempting to list all private user profiles fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', 'alice'), {
        name: 'Alice',
        email: 'alice@example.com',
      });
      await setDoc(doc(context.firestore(), 'users', 'bob'), {
        name: 'Bob',
        email: 'bob@example.com',
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    // Querying the private users collection fails because users can only read their own doc
    await assertFails(getDocs(collection(aliceDb, 'users')));
  });

  // 2. A user attempting to read another user's private email
  it('2. A user attempting to read another user private email fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', 'bob'), {
        name: 'Bob',
        email: 'bob.private@example.com',
        provider: 'email',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'public_users', 'bob'), {
        id: 'bob',
        name: 'Bob',
        photoUrl: null,
        isOnline: false,
        lastSeen: null,
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice CANNOT read Bob's private profile document
    await assertFails(getDoc(doc(aliceDb, 'users', 'bob')));

    // Alice CAN read Bob's public user discovery document
    const bobPublic = await assertSucceeds(getDoc(doc(aliceDb, 'public_users', 'bob')));
    // Confirm public doc does not expose private email
    const data = bobPublic.data();
    if (data && 'email' in data) {
      throw new Error('Public user discovery document must not contain email');
    }
  });

  // 3. A user attempting to modify their own isOnline field
  it('3. A user attempting to modify their own isOnline field fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', 'alice'), {
        name: 'Alice',
        email: 'alice@example.com',
        isOnline: false,
        lastSeen: null,
      });
      await setDoc(doc(context.firestore(), 'public_users', 'alice'), {
        id: 'alice',
        name: 'Alice',
        photoUrl: null,
        isOnline: false,
        lastSeen: null,
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice CANNOT set isOnline on /users/alice (server-authoritative)
    await assertFails(
      updateDoc(doc(aliceDb, 'users', 'alice'), {
        isOnline: true,
      })
    );

    // Alice CANNOT set isOnline on /public_users/alice (server-authoritative)
    await assertFails(
      updateDoc(doc(aliceDb, 'public_users', 'alice'), {
        isOnline: true,
      })
    );
  });

  // 4. A user attempting to modify server-controlled role or privilege fields
  it('4. A user attempting to modify server-controlled role or privilege fields fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', 'alice'), {
        name: 'Alice',
        email: 'alice@example.com',
        provider: 'email',
        isOnline: false,
        lastSeen: null,
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // User attempts to inject an admin role
    await assertFails(
      updateDoc(doc(aliceDb, 'users', 'alice'), {
        role: 'admin',
      })
    );

    // User attempts to alter immutable email field
    await assertFails(
      updateDoc(doc(aliceDb, 'users', 'alice'), {
        email: 'attacker@evil.com',
      })
    );

    // Allowed: User updates allowed presentation fields (name, photoUrl, updatedAt)
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'users', 'alice'), {
        name: 'Alice Smith',
      })
    );
  });

  // 5. A direct conversation participant attempting to modify adminIds
  it('5. A direct conversation participant attempting to modify adminIds fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        adminIds: ['alice'],
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice attempts to alter adminIds on a direct conversation
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob'), {
        adminIds: ['alice', 'charlie'],
      })
    );
  });

  // 6. A direct conversation participant attempting to alter another participant's profile snapshot
  it('6. A direct conversation participant attempting to alter another participant profile snapshot fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        participants: {
          alice: { id: 'alice', name: 'Alice' },
          bob: { id: 'bob', name: 'Bob' },
        },
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice attempts to alter Bob's participant snapshot
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob'), {
        'participants.bob.name': 'Impostor Bob',
      })
    );
  });

  // 7. A non-admin group member attempting to modify participants
  it('7. A non-admin group member attempting to modify participants fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_eng'), {
        type: 'group',
        groupName: 'Engineering',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'], // Alice is admin, Bob is regular member
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob attempts to add Charlie to participantIds
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_eng'), {
        participantIds: ['alice', 'bob', 'charlie'],
      })
    );
  });

  // 8. A non-admin group member attempting to modify lastMessageSenderId or protected metadata
  it('8. A non-admin group member attempting to modify lastMessageSenderId to someone else fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_eng'), {
        type: 'group',
        groupName: 'Engineering',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob attempts to impersonate Alice in the conversation preview
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_eng'), {
        lastMessage: 'I resign from the company',
        lastMessageSenderId: 'alice',
      })
    );

    // Bob attempts to change the group name
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_eng'), {
        groupName: 'Hacked Engineering Team',
      })
    );
  });

  // 9. A group administrator attempting to change immutable conversation fields
  it('9. A group administrator attempting to change immutable conversation fields fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_eng'), {
        type: 'group',
        groupName: 'Engineering',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice (admin) attempts to change conversation type to direct
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'group_eng'), {
        type: 'direct',
      })
    );

    // Alice attempts to alter createdBy
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'group_eng'), {
        createdBy: 'bob',
      })
    );
  });

  // 10. A message sender attempting to modify protected message metadata
  it('10. A message sender attempting to modify protected message metadata fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob', 'messages', 'msg_1'), {
        senderId: 'alice',
        text: 'Initial message',
        type: 'text',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice attempts to reassign the senderId of an existing message
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_1'), {
        senderId: 'bob',
      })
    );

    // Alice attempts to alter the creation timestamp
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_1'), {
        createdAt: serverTimestamp(),
      })
    );

    // Allowed: Alice edits text content with editedAt timestamp
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_1'), {
        text: 'Edited message content',
        editedAt: serverTimestamp(),
      })
    );
  });

  // 11. A non-participant attempting to access message subcollections
  it('11. A non-participant attempting to access message subcollections fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob', 'messages', 'secret_msg'), {
        senderId: 'alice',
        text: 'Confidential project details',
        type: 'text',
        createdAt: serverTimestamp(),
      });
    });

    const charlieDb = testEnv.authenticatedContext('charlie').firestore();

    // Charlie (non-participant) cannot read messages
    await assertFails(getDoc(doc(charlieDb, 'conversations', 'alice_bob', 'messages', 'secret_msg')));

    // Charlie cannot insert messages
    await assertFails(
      setDoc(doc(charlieDb, 'conversations', 'alice_bob', 'messages', 'charlie_spy'), {
        senderId: 'charlie',
        text: 'I am eavesdropping',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 12. Valid participants performing permitted message and read-state updates
  it('12. Valid participants performing permitted message and read-state updates succeed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        lastReadAtByUser: {
          alice: serverTimestamp(),
          bob: serverTimestamp(),
        },
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Alice creates a valid new message
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_new'), {
        senderId: 'alice',
        senderName: 'Alice',
        text: 'Hello Bob!',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );

    // Alice updates the conversation preview with her own sender ID
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob'), {
        lastMessage: 'Hello Bob!',
        lastMessageSenderId: 'alice',
        lastMessageSenderName: 'Alice',
      })
    );

    // Alice updates her own read receipt
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob'), {
        'lastReadAtByUser.alice': serverTimestamp(),
      })
    );

    // Alice attempts to alter Bob's read receipt -> rejected
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob'), {
        'lastReadAtByUser.bob': serverTimestamp(),
      })
    );
  });

  // 13. Deterministic Direct Conversation ID Enforcement
  it('13. Direct conversation creation enforces deterministic document ID (min_max)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // 'alice' < 'bob', so valid ID is 'alice_bob'
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );

    // Non-deterministic ID 'bob_alice' or random ID must be rejected by rules
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'bob_alice'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );

    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'random_direct_id_123'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 14. Storage Attachments and RTDB Isolation
  it('14. Storage attachments and Realtime Database presence isolate access', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceStorage = testEnv.authenticatedContext('alice').storage();
    const charlieStorage = testEnv.authenticatedContext('charlie').storage();
    const aliceRtdb = testEnv.authenticatedContext('alice').database();
    const bobRtdb = testEnv.authenticatedContext('bob').database();

    // Alice (participant) can upload conversation attachment
    await assertSucceeds(
      aliceStorage.ref('conversations/alice_bob/file.pdf').put(Buffer.from('report'), {
        contentType: 'application/pdf',
      })
    );

    // Charlie (non-participant) CANNOT upload or download
    await assertFails(
      charlieStorage.ref('conversations/alice_bob/file.pdf').put(Buffer.from('hack'), {
        contentType: 'application/pdf',
      })
    );

    // Alice can set her own RTDB device connection and lastSeen
    await assertSucceeds(aliceRtdb.ref('status/alice/connections/phone_1').set(true));
    await assertSucceeds(aliceRtdb.ref('status/alice/lastSeen').set(1710000000));

    // Bob CANNOT alter Alice's RTDB presence or lastSeen
    await assertFails(bobRtdb.ref('status/alice/connections/phone_1').set(false));
    await assertFails(bobRtdb.ref('status/alice/lastSeen').set(9999999));
  });

  // --------------------------------------------------------------------------
  // Phase 4.1 New Regression Tests: User Creation Hardening (Section 3)
  // --------------------------------------------------------------------------
  it('15. User creation hardening: normal profile creation succeeds', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    await assertSucceeds(
      setDoc(doc(aliceDb, 'users', 'alice'), {
        name: 'Alice Cooper',
        email: 'alice@example.com',
        photoUrl: null,
        lastSeen: null,
        isOnline: false,
        provider: 'email',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('16. User creation hardening: injecting role: admin or privilege fields fails', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Attempting to set role: 'admin'
    await assertFails(
      setDoc(doc(aliceDb, 'users', 'alice'), {
        name: 'Alice Cooper',
        email: 'alice@example.com',
        role: 'admin',
        isOnline: false,
        lastSeen: null,
        provider: 'email',
        createdAt: serverTimestamp(),
      })
    );

    // Attempting to inject arbitrary privilege or status
    await assertFails(
      setDoc(doc(aliceDb, 'users', 'alice'), {
        name: 'Alice Cooper',
        email: 'alice@example.com',
        status: 'verified',
        privilege: 'superadmin',
        isOnline: false,
        lastSeen: null,
        provider: 'email',
        createdAt: serverTimestamp(),
      })
    );

    // Attempting to start as isOnline: true
    await assertFails(
      setDoc(doc(aliceDb, 'users', 'alice'), {
        name: 'Alice Cooper',
        email: 'alice@example.com',
        isOnline: true,
        lastSeen: null,
        provider: 'email',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('17. User creation hardening: unexpected arbitrary fields fail', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    await assertFails(
      setDoc(doc(aliceDb, 'users', 'alice'), {
        name: 'Alice Cooper',
        email: 'alice@example.com',
        unexpectedField: 'malicious',
        isOnline: false,
        lastSeen: null,
        provider: 'email',
        createdAt: serverTimestamp(),
      })
    );
  });

  // --------------------------------------------------------------------------
  // Phase 4.1 New Regression Tests: Message Schema Allowlist (Section 5)
  // --------------------------------------------------------------------------
  it('18. Message schema: valid text, image, and file messages succeed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Valid text message
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_txt'), {
        senderId: 'alice',
        senderName: 'Alice',
        text: 'Normal text message',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );

    // Valid image message
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_img'), {
        senderId: 'alice',
        text: 'https://firebasestorage.googleapis.com/v0/b/.../photo.jpg',
        type: 'image',
        createdAt: serverTimestamp(),
      })
    );

    // Valid file message
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_file'), {
        senderId: 'alice',
        text: 'https://firebasestorage.googleapis.com/v0/b/.../document.pdf',
        type: 'file',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('19. Message schema: invalid type, spoofed sender, empty, and oversized text fail', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Spoofed senderId (Bob's ID while logged in as Alice)
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_bad_sender'), {
        senderId: 'bob',
        text: 'Spoofed message',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );

    // Unsupported message type
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_bad_type'), {
        senderId: 'alice',
        text: 'Audio payload',
        type: 'audio',
        createdAt: serverTimestamp(),
      })
    );

    // Empty text
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_empty'), {
        senderId: 'alice',
        text: '',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );

    // Oversized text (> 2000 chars)
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_oversized'), {
        senderId: 'alice',
        text: 'x'.repeat(2001),
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );

    // Injected unauthorized field on creation
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_injected'), {
        senderId: 'alice',
        text: 'Payload',
        type: 'text',
        createdAt: serverTimestamp(),
        deletedAt: serverTimestamp(), // Attempting soft-delete on creation
      })
    );
  });

  it('20. Message schema: message edit requires timestamp editedAt and only text is mutable', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob'), {
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'alice_bob', 'messages', 'msg_to_edit'), {
        senderId: 'alice',
        text: 'Original message',
        type: 'text',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Valid edit with editedAt timestamp
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_to_edit'), {
        text: 'Updated message',
        editedAt: serverTimestamp(),
      })
    );

    // Invalid edit: editedAt is not a timestamp
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_to_edit'), {
        text: 'Updated message 2',
        editedAt: 'yesterday',
      })
    );

    // Invalid edit: attempting to alter type or senderId
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'alice_bob', 'messages', 'msg_to_edit'), {
        type: 'image',
      })
    );
  });

  // --------------------------------------------------------------------------
  // Phase 4.1 New Regression Tests: Internal Collections Lockdown
  // --------------------------------------------------------------------------
  it('21. Internal metadata collections (_rate_limits, _function_events, _cleanup_progress) are completely denied to clients', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    await assertFails(getDoc(doc(aliceDb, '_rate_limits', 'alice')));
    await assertFails(setDoc(doc(aliceDb, '_rate_limits', 'alice'), { count: 0 }));

    await assertFails(getDoc(doc(aliceDb, '_function_events', 'evt_1')));
    await assertFails(setDoc(doc(aliceDb, '_function_events', 'evt_1'), { state: 'sent' }));

    await assertFails(getDoc(doc(aliceDb, '_cleanup_progress', 'alice')));
    await assertFails(setDoc(doc(aliceDb, '_cleanup_progress', 'alice'), { completed: true }));
  });
});
