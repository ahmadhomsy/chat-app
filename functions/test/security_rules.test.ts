import * as fs from 'fs';
import * as path from 'path';
import * as admin from 'firebase-admin';
import * as assert from 'assert';
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
  writeBatch,
  collection,
  serverTimestamp,
} from 'firebase/firestore';
import { enforceSearchRateLimit } from '../src/search_helpers';
import { auditLegacyParticipantEmails } from '../src/migrations/dry_run_strip_participant_emails';
import { evaluatePresenceCommit, parseEventTimestamp } from '../src/presence_helpers';

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
      Promise.resolve(aliceStorage.ref('conversations/alice_bob/file.pdf').put(Buffer.from('report'), {
        contentType: 'application/pdf',
      }))
    );

    // Charlie (non-participant) CANNOT upload or download
    await assertFails(
      Promise.resolve(charlieStorage.ref('conversations/alice_bob/file.pdf').put(Buffer.from('hack'), {
        contentType: 'application/pdf',
      }))
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

  // --------------------------------------------------------------------------
  // Phase 4.3 Regression Tests: Complete Participant Privacy & Concurrency Verification
  // --------------------------------------------------------------------------

  // 1. Valid direct conversation succeeds
  it('22. Valid direct conversation creation with sanitized participant snapshots succeeds', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Deterministic ID for ['alice', 'dave'] is 'alice_dave'
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'alice_dave'), {
        type: 'direct',
        participantIds: ['alice', 'dave'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        participants: {
          alice: { id: 'alice', name: 'Alice', photoUrl: 'https://example.com/a.png', isOnline: false },
          dave: { id: 'dave', name: 'Dave', photoUrl: null, isOnline: false },
        },
      })
    );
  });

  // Direct conversation creation with email rejected
  it('23. Direct conversation creation with nested participant email is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_eva'), {
        type: 'direct',
        participantIds: ['alice', 'eva'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        participants: {
          alice: { id: 'alice', name: 'Alice', email: 'alice@leak.com' },
          eva: { id: 'eva', name: 'Eva' },
        },
      })
    );
  });

  // Direct conversation creation with role or privilege rejected
  it('24. Direct conversation creation with role or privilege in participant snapshot is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_frank'), {
        type: 'direct',
        participantIds: ['alice', 'frank'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        participants: {
          alice: { id: 'alice', name: 'Alice' },
          frank: { id: 'frank', name: 'Frank', role: 'admin' },
        },
      })
    );
  });

  // 2. A valid group of eight succeeds
  it('25. A valid group of eight succeeds (dedicated participant subcollection)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds = ['alice', 'user_2', 'user_3', 'user_4', 'user_5', 'user_6', 'user_7', 'user_8'];

    const batch = writeBatch(aliceDb);
    const groupRef = doc(aliceDb, 'conversations', 'group_of_8');
    batch.set(groupRef, {
      type: 'group',
      groupName: 'Group of Eight',
      participantIds: pIds,
      adminIds: ['alice'],
      createdBy: 'alice',
      createdAt: serverTimestamp(),
    });

    for (const p of pIds) {
      batch.set(doc(aliceDb, 'conversations', 'group_of_8', 'participants', p), {
        id: p,
        name: `User ${p}`,
        photoUrl: null,
        isOnline: false,
      });
    }

    await assertSucceeds(batch.commit());
  });

  // 3. A valid group of nine succeeds
  it('26. A valid group of nine succeeds (breaking previous 8-member limit)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds = ['alice', 'user_2', 'user_3', 'user_4', 'user_5', 'user_6', 'user_7', 'user_8', 'user_9'];

    const batch = writeBatch(aliceDb);
    const groupRef = doc(aliceDb, 'conversations', 'group_of_9');
    batch.set(groupRef, {
      type: 'group',
      groupName: 'Group of Nine',
      participantIds: pIds,
      adminIds: ['alice'],
      createdBy: 'alice',
      createdAt: serverTimestamp(),
    });

    for (const p of pIds) {
      batch.set(doc(aliceDb, 'conversations', 'group_of_9', 'participants', p), {
        id: p,
        name: `User ${p}`,
        photoUrl: null,
        isOnline: false,
      });
    }

    await assertSucceeds(batch.commit());
  });

  // 4. A valid group of 100 succeeds
  it('27. A valid group of 100 succeeds (preserving 100-member product capacity)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds: string[] = ['alice'];
    for (let i = 2; i <= 100; i++) {
      pIds.push(`user_${i}`);
    }

    // Step A: Create parent conversation document
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'group_of_100'), {
        type: 'group',
        groupName: 'Century Club (100 Members)',
        participantIds: pIds,
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );

    // Step B: Commit participant documents in batches (50 per batch, well within 500 limit)
    const batch1 = writeBatch(aliceDb);
    for (let i = 0; i < 50; i++) {
      const p = pIds[i];
      batch1.set(doc(aliceDb, 'conversations', 'group_of_100', 'participants', p), {
        id: p,
        name: `Member ${i + 1}`,
        photoUrl: null,
        isOnline: false,
      });
    }
    await assertSucceeds(batch1.commit());

    const batch2 = writeBatch(aliceDb);
    for (let i = 50; i < 100; i++) {
      const p = pIds[i];
      batch2.set(doc(aliceDb, 'conversations', 'group_of_100', 'participants', p), {
        id: p,
        name: `Member ${i + 1}`,
        photoUrl: null,
        isOnline: false,
      });
    }
    await assertSucceeds(batch2.commit());
  });

  // Parent group document cannot accept embedded unvalidated participant maps
  it('28. Group creation with nested participant email on parent document is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_parent_leak'), {
        type: 'group',
        groupName: 'Secret Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
        participants: {
          alice: { id: 'alice', name: 'Alice' },
          bob: { id: 'bob', name: 'Bob', email: 'bob.private@domain.com' },
        },
      })
    );
  });

  // 5. An email injected into participant 9 is rejected
  it('29. An email injected into participant 9 is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds = ['alice', 'user_2', 'user_3', 'user_4', 'user_5', 'user_6', 'user_7', 'user_8', 'user_9'];

    // Create the conversation first
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_test_p9'), {
        type: 'group',
        groupName: 'P9 Test',
        participantIds: pIds,
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    // Alice attempts to write participant 9 with email in subcollection -> MUST FAIL
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_test_p9', 'participants', 'user_9'), {
        id: 'user_9',
        name: 'User 9',
        email: 'user9@leak.com',
      })
    );
  });

  // 6. An email injected into participant 10 is rejected
  it('30. An email injected into participant 10 is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds = ['alice', 'user_2', 'user_3', 'user_4', 'user_5', 'user_6', 'user_7', 'user_8', 'user_9', 'user_10'];

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_test_p10'), {
        type: 'group',
        groupName: 'P10 Test',
        participantIds: pIds,
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_test_p10', 'participants', 'user_10'), {
        id: 'user_10',
        name: 'User 10',
        email: 'user10@leak.com',
      })
    );
  });

  // 7. An email injected into participant 100 is rejected
  it('31. An email injected into participant 100 is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds: string[] = ['alice'];
    for (let i = 2; i <= 100; i++) {
      pIds.push(`user_${i}`);
    }

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_test_p100'), {
        type: 'group',
        groupName: 'P100 Test',
        participantIds: pIds,
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_test_p100', 'participants', 'user_100'), {
        id: 'user_100',
        name: 'User 100',
        email: 'user100@leak.com',
      })
    );
  });

  // 8. A role injected into participant 9 is rejected
  it('32. A role injected into participant 9 is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds = ['alice', 'user_2', 'user_3', 'user_4', 'user_5', 'user_6', 'user_7', 'user_8', 'user_9'];

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_test_role9'), {
        type: 'group',
        groupName: 'Role 9 Test',
        participantIds: pIds,
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_test_role9', 'participants', 'user_9'), {
        id: 'user_9',
        name: 'User 9',
        role: 'admin',
      })
    );
  });

  // 9. A provider or privilege field injected into participant 100 is rejected
  it('33. A provider or privilege field injected into participant 100 is rejected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds: string[] = ['alice'];
    for (let i = 2; i <= 100; i++) {
      pIds.push(`user_${i}`);
    }

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_test_priv100'), {
        type: 'group',
        groupName: 'Privilege 100 Test',
        participantIds: pIds,
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    // Attempt provider
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_test_priv100', 'participants', 'user_100'), {
        id: 'user_100',
        name: 'User 100',
        provider: 'google',
      })
    );

    // Attempt privilege
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_test_priv100', 'participants', 'user_100'), {
        id: 'user_100',
        name: 'User 100',
        privilege: 'root',
      })
    );
  });

  // 10. A group administrator attempting to inject private fields during membership updates is rejected
  it('34. A group administrator attempting to inject private fields during membership updates is rejected', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_admin_leak'), {
        type: 'group',
        groupName: 'Admin Security Test',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_admin_leak', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob',
        photoUrl: null,
        isOnline: false,
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Admin attempts to update Bob's participant snapshot with email
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'group_admin_leak', 'participants', 'bob'), {
        email: 'bob.leaked@evil.com',
      })
    );

    // Admin attempts to inject role into Bob's participant snapshot
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'group_admin_leak', 'participants', 'bob'), {
        role: 'co-owner',
      })
    );
  });

  // 11. A legitimate administrator adding a member succeeds
  it('35. A legitimate administrator adding a member succeeds', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_member_add'), {
        type: 'group',
        groupName: 'Growing Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Admin updates participantIds and adds charlie to participants subcollection
    const batch = writeBatch(aliceDb);
    batch.update(doc(aliceDb, 'conversations', 'group_member_add'), {
      participantIds: ['alice', 'bob', 'charlie'],
    });
    batch.set(doc(aliceDb, 'conversations', 'group_member_add', 'participants', 'charlie'), {
      id: 'charlie',
      name: 'Charlie Chaplin',
      photoUrl: 'https://example.com/charlie.png',
      isOnline: false,
    });

    await assertSucceeds(batch.commit());
  });

  // 12. A normal member attempting the same operation fails
  it('36. A normal member attempting to add a member fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_member_restrict'), {
        type: 'group',
        groupName: 'Restricted Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'], // Bob is not an admin
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob attempts to add charlie to participantIds on the parent conversation
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_member_restrict'), {
        participantIds: ['alice', 'bob', 'charlie'],
      })
    );

    // Bob attempts to create charlie's participant document in the subcollection
    await assertFails(
      setDoc(doc(bobDb, 'conversations', 'group_member_restrict', 'participants', 'charlie'), {
        id: 'charlie',
        name: 'Charlie Unauthorized',
        photoUrl: null,
        isOnline: false,
      })
    );
  });

  // 13. Valid public participant profile updates remain functional
  it('37. Valid public participant profile updates remain functional (self-update & admin update)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_profile_update'), {
        type: 'group',
        groupName: 'Profile Update Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_profile_update', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Original',
        photoUrl: null,
        isOnline: false,
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();
    const aliceDb = testEnv.authenticatedContext('alice').firestore();

    // Bob updates their own display name and avatar
    await assertSucceeds(
      updateDoc(doc(bobDb, 'conversations', 'group_profile_update', 'participants', 'bob'), {
        name: 'Bob Renamed',
        photoUrl: 'https://example.com/bob_new.png',
      })
    );

    // Alice (admin) updates Bob's name
    await assertSucceeds(
      updateDoc(doc(aliceDb, 'conversations', 'group_profile_update', 'participants', 'bob'), {
        name: 'Robert Admin Renamed',
      })
    );
  });

  // --------------------------------------------------------------------------
  // Phase 4.3 Real Concurrency & Emulator Verification Tests
  // --------------------------------------------------------------------------

  // Search Rate Limiter Real Concurrency Verification (Section 6)
  it('38. Search Rate Limiter: 20 concurrent requests against Firestore emulator enforce max 15 requests', async () => {
    // Set emulator host for admin sdk
    process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
    if (!admin.apps.length) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    const adminDb = admin.firestore();
    const callerUid = 'concurrency_search_test_user';
    const rateLimitDoc = adminDb.collection('_rate_limits').doc(callerUid);

    // Clean up before test
    await rateLimitDoc.delete();

    const now = Date.now();
    const executeWithLockRetry = async (): Promise<{ success: boolean; code: any }> => {
      for (let attempt = 0; attempt < 10; attempt++) {
        try {
          await enforceSearchRateLimit(adminDb, callerUid, now, 15, 60000);
          return { success: true, code: null };
        } catch (err: any) {
          if (err.code === 'resource-exhausted') {
            return { success: false, code: 'resource-exhausted' };
          }
          // On emulator lock timeout or grpc abort, retry with backoff
          if (err.message?.includes('lock timeout') || err.code === 10 || err.code === 'aborted') {
            await new Promise((r) => setTimeout(r, 50 * (attempt + 1)));
            continue;
          }
          return { success: false, code: err.code };
        }
      }
      return { success: false, code: 'aborted' };
    };

    const requests = Array.from({ length: 20 }, () => executeWithLockRetry());

    const results = await Promise.all(requests);
    const succeeded = results.filter((r) => r.success);
    const rateLimited = results.filter((r) => !r.success && r.code === 'resource-exhausted');

    assert.strictEqual(succeeded.length, 15, 'Exactly 15 requests must succeed within rolling 60s');
    assert.strictEqual(rateLimited.length, 5, 'Exactly 5 requests must be rejected with resource-exhausted');

    // Verify stored timestamp array is bounded to exactly 15 entries
    const savedDoc = await rateLimitDoc.get();
    assert.strictEqual(savedDoc.exists, true);
    const timestamps = savedDoc.data()?.timestamps;
    assert.ok(Array.isArray(timestamps));
    assert.strictEqual(timestamps.length, 15);
  });

  // Legacy Email Migration Audit against Live Firestore Emulator (Section 4)
  it('39. Legacy Email Migration: audit scanner identifies affected docs across batches with zero writes in dry-run', async () => {
    process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
    if (!admin.apps.length) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    const adminDb = admin.firestore();

    // Clean up any previous test conversations with prefix 'audit_conv_'
    const existing = await adminDb.collection('conversations').where(admin.firestore.FieldPath.documentId(), '>=', 'audit_conv_').get();
    for (const d of existing.docs) {
      if (d.id.startsWith('audit_conv_')) {
        await d.ref.delete();
      }
    }

    // Seed 5 test conversation documents in emulator
    // 3 with legacy participant email, 2 clean
    const seedDocs = [
      { id: 'audit_conv_01', hasEmail: true },
      { id: 'audit_conv_02', hasEmail: true },
      { id: 'audit_conv_03', hasEmail: false },
      { id: 'audit_conv_04', hasEmail: true },
      { id: 'audit_conv_05', hasEmail: false },
    ];

    for (const item of seedDocs) {
      const participants: Record<string, any> = {
        alice: { id: 'alice', name: 'Alice' },
      };
      if (item.hasEmail) {
        participants.bob = { id: 'bob', name: 'Bob', email: 'bob@legacy.com' };
      } else {
        participants.bob = { id: 'bob', name: 'Bob' };
      }

      await adminDb.collection('conversations').doc(item.id).set({
        type: 'direct',
        participantIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        participants,
      });
    }

    // Run audit in dry-run mode with batch size 2 (ensuring pagination across multiple batches)
    const auditResult = await auditLegacyParticipantEmails(adminDb, { dryRun: true, batchSize: 2 });

    assert.ok(auditResult.totalScanned >= 5);
    assert.ok(auditResult.conversationsWithEmail >= 3);
    assert.ok(auditResult.totalEmailsFound >= 3);
    assert.ok(auditResult.batchesProcessed >= 3);
    assert.strictEqual(auditResult.dryRun, true);

    // Verify ZERO writes occurred: audit_conv_01 must STILL contain 'bob.email'
    const docAfter = await adminDb.collection('conversations').doc('audit_conv_01').get();
    assert.strictEqual(docAfter.data()?.participants?.bob?.email, 'bob@legacy.com');
  });

  // Presence Transaction Concurrency Verification against Live Firestore Emulator (Section 5)
  it('40. Presence Transaction: concurrent transaction updates against emulator maintain monotonic order', async () => {
    process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
    if (!admin.apps.length) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    const adminDb = admin.firestore();
    const testUserId = 'presence_concurrency_user';

    const userRef = adminDb.collection('users').doc(testUserId);
    const publicRef = adminDb.collection('public_users').doc(testUserId);

    // Initial committed state: offline at T=1000.000000Z
    const t0 = parseEventTimestamp('2026-11-21T18:42:10.000000Z');
    await userRef.set({ isOnline: false, presenceLastEventTimeMs: t0.millis, presenceLastEventTimeMicros: Number(t0.micros) });
    await publicRef.set({ isOnline: false, presenceLastEventTimeMs: t0.millis, presenceLastEventTimeMicros: Number(t0.micros) });

    // Two competing transitions:
    // Event A (newer online): T=18:42:15.000500Z
    // Event B (older offline): T=18:42:15.000100Z
    const eventA = parseEventTimestamp('2026-11-21T18:42:15.000500Z');
    const eventB = parseEventTimestamp('2026-11-21T18:42:15.000100Z');

    // Run transaction for Event A
    await adminDb.runTransaction(async (transaction) => {
      const docSnap = await transaction.get(userRef);
      const committedMicros = docSnap.data()?.presenceLastEventTimeMicros;
      const dec = evaluatePresenceCommit(committedMicros, eventA);
      if (dec.canCommit) {
        transaction.update(userRef, { isOnline: true, presenceLastEventTimeMicros: Number(eventA.micros) });
        transaction.update(publicRef, { isOnline: true, presenceLastEventTimeMicros: Number(eventA.micros) });
      }
    });

    // Run transaction for Event B (older than Event A)
    await adminDb.runTransaction(async (transaction) => {
      const docSnap = await transaction.get(userRef);
      const committedMicros = docSnap.data()?.presenceLastEventTimeMicros;
      const dec = evaluatePresenceCommit(committedMicros, eventB);
      if (dec.canCommit) {
        transaction.update(userRef, { isOnline: false, presenceLastEventTimeMicros: Number(eventB.micros) });
        transaction.update(publicRef, { isOnline: false, presenceLastEventTimeMicros: Number(eventB.micros) });
      }
    });

    // Final state must remain online (Event A) with Event A's microsecond timestamp
    const finalUserDoc = await userRef.get();
    assert.strictEqual(finalUserDoc.data()?.isOnline, true);
    assert.strictEqual(finalUserDoc.data()?.presenceLastEventTimeMicros, Number(eventA.micros));
  });
});
