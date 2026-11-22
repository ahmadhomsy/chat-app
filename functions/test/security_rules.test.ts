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
  deleteDoc,
  writeBatch,
  collection,
  serverTimestamp,
} from 'firebase/firestore';
import { enforceSearchRateLimit } from '../src/search_helpers';
import { auditLegacyParticipantEmails } from '../src/migrations/dry_run_strip_participant_emails';
import {
  commitUserPresenceTransaction,
  parseEventTimestamp,
} from '../src/presence_helpers';

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

  // 4. A valid group of 100 succeeds (exact production flow: 1 parent doc + 100 participant subdocuments in a single WriteBatch)
  it('27. A valid group of 100 succeeds (exact production flow: parent + 100 participants in a single WriteBatch)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds: string[] = ['alice'];
    for (let i = 2; i <= 100; i++) {
      pIds.push(`user_${i}`);
    }

    const batch = writeBatch(aliceDb);
    const groupRef = doc(aliceDb, 'conversations', 'group_of_100_single_batch');

    // 1 parent conversation document
    batch.set(groupRef, {
      type: 'group',
      groupName: 'Century Club Single Batch (100 Members)',
      participantIds: pIds,
      adminIds: ['alice'],
      createdBy: 'alice',
      createdAt: serverTimestamp(),
    });

    // 100 participant subdocuments created in the exact same WriteBatch (101 writes total)
    for (const p of pIds) {
      batch.set(doc(aliceDb, 'conversations', 'group_of_100_single_batch', 'participants', p), {
        id: p,
        name: `Member ${p}`,
        photoUrl: null,
        isOnline: false,
      });
    }

    // Verify all 101 operations commit in one single atomic WriteBatch via getAfter() evaluation
    await assertSucceeds(batch.commit());

    // Verify parent document exists
    const groupSnap = await getDoc(groupRef);
    assert.strictEqual(groupSnap.exists(), true);
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
      for (let attempt = 0; attempt < 30; attempt++) {
        try {
          await enforceSearchRateLimit(adminDb, callerUid, now, 15, 60000);
          return { success: true, code: null };
        } catch (err: any) {
          if (err.code === 'resource-exhausted') {
            return { success: false, code: 'resource-exhausted' };
          }
          // On emulator lock timeout or grpc abort, retry with backoff and jitter
          if (
            err.message?.toLowerCase().includes('lock timeout') ||
            err.message?.includes('ABORTED') ||
            err.code === 10 ||
            err.code === 'aborted'
          ) {
            await new Promise((r) => setTimeout(r, 20 + Math.random() * 30 * (attempt + 1)));
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

  // Presence Transaction True Concurrency Verification against Live Firestore Emulator (Section 6)
  it('40. Presence Transaction: true concurrent competing transactions against emulator maintain monotonic order', async () => {
    process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
    if (!admin.apps.length) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    const adminDb = admin.firestore();
    const testUserId = 'presence_true_concurrency_user';

    const userRef = adminDb.collection('users').doc(testUserId);
    const publicRef = adminDb.collection('public_users').doc(testUserId);

    // Initial committed baseline: offline at T0 (18:42:00.000000Z)
    const t0 = parseEventTimestamp('2026-11-21T18:42:00.000000Z');
    await userRef.set({ isOnline: false, presenceLastEventTimeMs: t0.millis, presenceLastEventTimeMicros: Number(t0.micros), presenceLastEventTimeIso: t0.isoString });
    await publicRef.set({ isOnline: false, presenceLastEventTimeMs: t0.millis, presenceLastEventTimeMicros: Number(t0.micros), presenceLastEventTimeIso: t0.isoString });

    // Test Scenario A: Concurrent contention between Newer Online (T2) and Older Offline (T1)
    const t1Older = parseEventTimestamp('2026-11-21T18:42:10.000100Z'); // Older offline
    const t2Newer = parseEventTimestamp('2026-11-21T18:42:10.000500Z'); // Newer online (400 micros newer)

    // Barrier mechanism to ensure both transactions begin and read the baseline before either commits
    let readCountA = 0;
    let barrierResolveA: () => void;
    const barrierPromiseA = new Promise<void>((resolve) => {
      barrierResolveA = resolve;
    });

    const onBeforeCommitHookA = async () => {
      readCountA++;
      if (readCountA >= 2) {
        barrierResolveA();
      } else {
        await barrierPromiseA;
      }
    };

    // Run both competing transactions concurrently via Promise.all using the production helper
    await Promise.all([
      commitUserPresenceTransaction({
        firestore: adminDb,
        userId: testUserId,
        isOnline: false,
        incomingTimestamp: t1Older,
        onBeforeCommit: onBeforeCommitHookA,
      }),
      commitUserPresenceTransaction({
        firestore: adminDb,
        userId: testUserId,
        isOnline: true,
        incomingTimestamp: t2Newer,
        onBeforeCommit: onBeforeCommitHookA,
      }),
    ]);

    // Verify monotonic outcome: newer online state (T2) MUST win over older offline state (T1)
    const finalUserDocA = await userRef.get();
    const finalPublicDocA = await publicRef.get();

    assert.strictEqual(finalUserDocA.data()?.isOnline, true, 'User must remain online (newer event)');
    assert.strictEqual(finalPublicDocA.data()?.isOnline, true, 'Public user must remain online');
    assert.strictEqual(finalUserDocA.data()?.presenceLastEventTimeMicros, Number(t2Newer.micros));
    assert.strictEqual(finalPublicDocA.data()?.presenceLastEventTimeMicros, Number(t2Newer.micros));

    // Test Scenario B: Reverse scheduling order with simultaneous start
    // Dispatch older online (T3) vs newer offline (T4)
    const t3Older = parseEventTimestamp('2026-11-21T18:42:20.000100Z');
    const t4Newer = parseEventTimestamp('2026-11-21T18:42:20.000900Z');

    let readCountB = 0;
    let barrierResolveB: () => void;
    const barrierPromiseB = new Promise<void>((resolve) => {
      barrierResolveB = resolve;
    });

    const onBeforeCommitHookB = async () => {
      readCountB++;
      if (readCountB >= 2) {
        barrierResolveB();
      } else {
        await barrierPromiseB;
      }
    };

    await Promise.all([
      commitUserPresenceTransaction({
        firestore: adminDb,
        userId: testUserId,
        isOnline: true,
        incomingTimestamp: t3Older,
        onBeforeCommit: onBeforeCommitHookB,
      }),
      commitUserPresenceTransaction({
        firestore: adminDb,
        userId: testUserId,
        isOnline: false,
        incomingTimestamp: t4Newer,
        onBeforeCommit: onBeforeCommitHookB,
      }),
    ]);

    const finalUserDocB = await userRef.get();
    const finalPublicDocB = await publicRef.get();

    assert.strictEqual(finalUserDocB.data()?.isOnline, false, 'User must be offline (newer event)');
    assert.strictEqual(finalPublicDocB.data()?.isOnline, false, 'Public user must be offline');
    assert.strictEqual(finalUserDocB.data()?.presenceLastEventTimeMicros, Number(t4Newer.micros));
    assert.strictEqual(finalPublicDocB.data()?.presenceLastEventTimeMicros, Number(t4Newer.micros));
  });

  // --------------------------------------------------------------------------
  // Phase 4.3.1 Group Admin Authorization & Membership Invariant Tests (Section 4)
  // --------------------------------------------------------------------------

  // 1. Valid group with all administrators included in participantIds succeeds
  it('41. A valid group with all administrators included in participantIds succeeds', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const groupRef = doc(aliceDb, 'conversations', 'group_admin_valid');

    await assertSucceeds(
      setDoc(groupRef, {
        type: 'group',
        groupName: 'Authorized Admin Group',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice', 'bob'], // Both admins are participants
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 2. Creating a group with an administrator outside participantIds fails
  it('42. Creating a group with an administrator outside participantIds fails', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const groupRef = doc(aliceDb, 'conversations', 'group_admin_outsider');

    await assertFails(
      setDoc(groupRef, {
        type: 'group',
        groupName: 'Malicious Admin Group',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice', 'mallory'], // Mallory is NOT in participantIds
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 3. Creating a group with an empty administrator list fails
  it('43. Creating a group with an empty administrator list fails', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const groupRef = doc(aliceDb, 'conversations', 'group_empty_admins');

    await assertFails(
      setDoc(groupRef, {
        type: 'group',
        groupName: 'No Admin Group',
        participantIds: ['alice', 'bob'],
        adminIds: [], // Empty admin list violates invariant
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  // 4. A group administrator cannot add an outsider UID to adminIds
  it('44. A group administrator cannot add an outsider UID to adminIds during update', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_update_outsider'), {
        type: 'group',
        groupName: 'Update Outsider Test',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const groupRef = doc(aliceDb, 'conversations', 'group_update_outsider');

    // Alice attempts to add Mallory (non-participant) to adminIds
    await assertFails(
      updateDoc(groupRef, {
        adminIds: ['alice', 'mallory'],
      })
    );
  });

  // 5. A group administrator cannot leave a phantom administrator after removing a member
  it('45. A group administrator cannot leave a phantom administrator after removing a member', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_phantom_admin'), {
        type: 'group',
        groupName: 'Phantom Admin Test',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice', 'bob'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const groupRef = doc(aliceDb, 'conversations', 'group_phantom_admin');

    // Alice removes Bob from participantIds but leaves Bob in adminIds -> MUST FAIL
    await assertFails(
      updateDoc(groupRef, {
        participantIds: ['alice', 'charlie'], // Bob removed from participants but remains in adminIds
      })
    );
  });

  // 6. A valid administrator succession succeeds
  it('46. A valid administrator succession succeeds when new administrator is in participantIds', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_succession'), {
        type: 'group',
        groupName: 'Succession Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const groupRef = doc(aliceDb, 'conversations', 'group_succession');

    // Alice promotes Bob (who is a valid participant) to co-administrator
    await assertSucceeds(
      updateDoc(groupRef, {
        adminIds: ['alice', 'bob'],
      })
    );
  });

  // 7. A nonmember listed in a malicious adminIds payload cannot modify participant documents
  it('47. A nonmember listed in a malicious adminIds payload cannot modify participant documents', async () => {
    // Seed conversation with mallory in adminIds but NOT in participantIds
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_malicious_admin'), {
        type: 'group',
        groupName: 'Malicious Admin Bypass',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice', 'mallory'], // Mallory is outsider
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_malicious_admin', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Original',
        photoUrl: null,
        isOnline: false,
      });
    });

    const malloryDb = testEnv.authenticatedContext('mallory').firestore();

    // Mallory attempts to modify Bob's participant document
    await assertFails(
      updateDoc(doc(malloryDb, 'conversations', 'group_malicious_admin', 'participants', 'bob'), {
        name: 'Hacked by Mallory',
      })
    );
  });

  // 8. A nonmember listed in adminIds cannot delete participant documents
  it('48. A nonmember listed in adminIds cannot delete participant documents', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_malicious_delete'), {
        type: 'group',
        groupName: 'Malicious Delete Test',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice', 'mallory'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_malicious_delete', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob',
        photoUrl: null,
        isOnline: false,
      });
    });

    const malloryDb = testEnv.authenticatedContext('mallory').firestore();

    // Mallory attempts to delete Bob's participant document
    await assertFails(
      deleteDoc(doc(malloryDb, 'conversations', 'group_malicious_delete', 'participants', 'bob'))
    );
  });

  // 9. A removed member cannot update their previous participant document
  it('49. A removed member cannot update their previous participant document', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_member'), {
        type: 'group',
        groupName: 'Removed Member Test',
        participantIds: ['alice', 'charlie'], // Bob was removed
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_member', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Stale',
        photoUrl: null,
        isOnline: false,
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob (no longer a participant) attempts to update their old participant document
    await assertFails(
      updateDoc(doc(bobDb, 'conversations', 'group_removed_member', 'participants', 'bob'), {
        name: 'Bob Unauthorized Edit',
      })
    );
  });

  // 10. A removed member cannot delete their previous participant document
  it('50. A removed member cannot delete their previous participant document', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_delete'), {
        type: 'group',
        groupName: 'Removed Member Delete Test',
        participantIds: ['alice', 'charlie'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_delete', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Stale',
        photoUrl: null,
        isOnline: false,
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob attempts to delete their stale participant document
    await assertFails(
      deleteDoc(doc(bobDb, 'conversations', 'group_removed_delete', 'participants', 'bob'))
    );
  });

  // 11. A removed member cannot read participant subcollection documents
  it('51. A removed member cannot read participant subcollection documents', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_read'), {
        type: 'group',
        groupName: 'Removed Member Read Test',
        participantIds: ['alice', 'charlie'], // Bob not in participantIds
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_read', 'participants', 'alice'), {
        id: 'alice',
        name: 'Alice Private',
        photoUrl: null,
        isOnline: true,
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob attempts to read Alice's participant document in the subcollection
    await assertFails(
      getDoc(doc(bobDb, 'conversations', 'group_removed_read', 'participants', 'alice'))
    );
  });

  // 12. A current member can update only permitted own display fields
  it('52. A current member can update only permitted own display fields (name, photoUrl)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_member_self_update'), {
        type: 'group',
        groupName: 'Self Update Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_member_self_update', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Initial',
        photoUrl: null,
        isOnline: false,
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Bob updates their own name and photoUrl
    await assertSucceeds(
      updateDoc(doc(bobDb, 'conversations', 'group_member_self_update', 'participants', 'bob'), {
        name: 'Robert Updated',
        photoUrl: 'https://example.com/robert.png',
      })
    );
  });

  // 13. A current member cannot modify document ID, email, role, provider, or server-authoritative presence fields
  it('53. A current member cannot modify document ID, email, role, provider, or server-authoritative presence fields', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_member_tamper'), {
        type: 'group',
        groupName: 'Tamper Prevention Team',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_member_tamper', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Member',
        photoUrl: null,
        isOnline: false,
      });
    });

    const bobDb = testEnv.authenticatedContext('bob').firestore();
    const bobDoc = doc(bobDb, 'conversations', 'group_member_tamper', 'participants', 'bob');

    // Attempt to tamper with presence isOnline
    await assertFails(updateDoc(bobDoc, { isOnline: true }));

    // Attempt to tamper with presence lastSeen
    await assertFails(updateDoc(bobDoc, { lastSeen: serverTimestamp() }));

    // Attempt to inject email
    await assertFails(updateDoc(bobDoc, { email: 'bob@evil.com' }));

    // Attempt to inject role
    await assertFails(updateDoc(bobDoc, { role: 'admin' }));

    // Attempt to inject provider
    await assertFails(updateDoc(bobDoc, { provider: 'google' }));

    // Attempt to alter document ID field
    await assertFails(updateDoc(bobDoc, { id: 'impersonated_id' }));
  });

  // 14. A group administrator can remove a member using the intended secure atomic operation
  it('54. A group administrator can remove a member using the intended secure atomic operation', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_admin_remove_member'), {
        type: 'group',
        groupName: 'Removal Test Team',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_admin_remove_member', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Exiting',
        photoUrl: null,
        isOnline: false,
      });
    });

    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const bobDb = testEnv.authenticatedContext('bob').firestore();

    // Normal member (Bob) attempting to delete Alice's participant document -> MUST FAIL
    await assertFails(
      deleteDoc(doc(bobDb, 'conversations', 'group_admin_remove_member', 'participants', 'alice'))
    );

    // Alice atomically removes Bob from parent participantIds and deletes Bob's subcollection document
    const batch = writeBatch(aliceDb);
    batch.update(doc(aliceDb, 'conversations', 'group_admin_remove_member'), {
      participantIds: ['alice', 'charlie'],
    });
    batch.delete(doc(aliceDb, 'conversations', 'group_admin_remove_member', 'participants', 'bob'));

    await assertSucceeds(batch.commit());
  });

  // =========================================================================
  // Phase 4.3.2: Unique Participant IDs & Atomic Removal Tests (Sections 3 & 4)
  // =========================================================================

  // Section 3: Unique Participant IDs
  it('55. A valid group with unique member UIDs succeeds on creation', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'group_valid_unique'), {
        type: 'group',
        groupName: 'Unique Team',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('56. Group creation with duplicate participant UIDs fails', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    // 2-member list with duplicates: ['alice', 'alice']
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_dup_pids_1'), {
        type: 'group',
        groupName: 'Duplicate Test 1',
        participantIds: ['alice', 'alice'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
    // 3-member list with duplicate: ['alice', 'bob', 'alice']
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_dup_pids_2'), {
        type: 'group',
        groupName: 'Duplicate Test 2',
        participantIds: ['alice', 'bob', 'alice'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('57. Group creation with duplicate admin UIDs fails', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'group_dup_admin_ids'), {
        type: 'group',
        groupName: 'Duplicate Admin Test',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice', 'alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('58. A valid group of 100 unique members succeeds', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const pIds = ['alice'];
    for (let i = 2; i <= 100; i++) {
      pIds.push(`user_${i}`);
    }
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'group_100_unique'), {
        type: 'group',
        groupName: 'Centum Group',
        participantIds: pIds,
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('59. Updating a valid group with duplicate participant IDs fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_update_dup_pids'), {
        type: 'group',
        groupName: 'Update Dup Test',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'group_update_dup_pids'), {
        participantIds: ['alice', 'bob', 'alice'],
      })
    );
  });

  it('60. Updating a valid group with duplicate admin IDs fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_update_dup_admins'), {
        type: 'group',
        groupName: 'Update Dup Admin Test',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      updateDoc(doc(aliceDb, 'conversations', 'group_update_dup_admins'), {
        adminIds: ['alice', 'bob', 'alice'],
      })
    );
  });

  it('61. Direct conversation with duplicate participant IDs fails (self-conversation rejected)', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertFails(
      setDoc(doc(aliceDb, 'conversations', 'alice_alice'), {
        type: 'direct',
        participantIds: ['alice', 'alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('62. Normal valid direct conversation with two distinct UIDs continues to work', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    await assertSucceeds(
      setDoc(doc(aliceDb, 'conversations', 'alice_charlie'), {
        type: 'direct',
        participantIds: ['alice', 'charlie'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      })
    );
  });

  // Section 4: Atomic Participant Removal
  it('63. Administrator deleting another participant document alone (standalone deletion) fails', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_standalone_del'), {
        type: 'group',
        groupName: 'Standalone Delete Test',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_standalone_del', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob',
        photoUrl: null,
        isOnline: false,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    // Standalone deletion without updating parent conversation participantIds MUST fail
    await assertFails(
      deleteDoc(doc(aliceDb, 'conversations', 'group_standalone_del', 'participants', 'bob'))
    );
  });

  it('64. Administrator updating parent membership and deleting the participant document in one atomic batch succeeds', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_atomic_del_ok'), {
        type: 'group',
        groupName: 'Atomic Delete Success Test',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_atomic_del_ok', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob',
        photoUrl: null,
        isOnline: false,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const batch = writeBatch(aliceDb);
    batch.update(doc(aliceDb, 'conversations', 'group_atomic_del_ok'), {
      participantIds: ['alice', 'charlie'],
    });
    batch.delete(doc(aliceDb, 'conversations', 'group_atomic_del_ok', 'participants', 'bob'));
    await assertSucceeds(batch.commit());
  });

  it('65. Administrator cannot remove the last remaining valid administrator', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_remove_last_admin'), {
        type: 'group',
        groupName: 'Last Admin Protection',
        participantIds: ['alice', 'bob'],
        adminIds: ['alice'], // Alice is sole admin
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_remove_last_admin', 'participants', 'alice'), {
        id: 'alice',
        name: 'Alice Sole Admin',
        photoUrl: null,
        isOnline: true,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    // Alice attempts atomic batch removing herself leaving no valid admin
    const batch = writeBatch(aliceDb);
    batch.update(doc(aliceDb, 'conversations', 'group_remove_last_admin'), {
      participantIds: ['bob'],
      adminIds: [],
    });
    batch.delete(doc(aliceDb, 'conversations', 'group_remove_last_admin', 'participants', 'alice'));
    await assertFails(batch.commit());
  });

  it('66. Administrator cannot leave a removed admin inside adminIds', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_phantom_removal'), {
        type: 'group',
        groupName: 'Phantom Admin Prevention',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice', 'bob'], // Alice and Bob are admins
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_phantom_removal', 'participants', 'bob'), {
        id: 'bob',
        name: 'Bob Admin',
        photoUrl: null,
        isOnline: false,
      });
    });
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    // Alice removes Bob from participantIds and deletes his participant doc, but leaves Bob in adminIds
    const batch = writeBatch(aliceDb);
    batch.update(doc(aliceDb, 'conversations', 'group_phantom_removal'), {
      participantIds: ['alice', 'charlie'],
    });
    batch.delete(doc(aliceDb, 'conversations', 'group_phantom_removal', 'participants', 'bob'));
    await assertFails(batch.commit());
  });

  it('67. Removed member loses parent conversation read access', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_access'), {
        type: 'group',
        groupName: 'Post Removal Access Check',
        participantIds: ['alice', 'charlie'], // Bob was removed
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
    });
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    // Bob attempts to read the conversation document
    await assertFails(
      getDoc(doc(bobDb, 'conversations', 'group_removed_access'))
    );
  });

  it('68. Removed member loses participant subcollection access', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_subcol_access'), {
        type: 'group',
        groupName: 'Subcollection Access Check',
        participantIds: ['alice', 'charlie'], // Bob removed
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_removed_subcol_access', 'participants', 'charlie'), {
        id: 'charlie',
        name: 'Charlie',
        photoUrl: null,
        isOnline: false,
      });
    });
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    // Bob cannot read Charlie's participant snapshot
    await assertFails(
      getDoc(doc(bobDb, 'conversations', 'group_removed_subcol_access', 'participants', 'charlie'))
    );
  });

  it('69. Remaining members retain normal read and message operations after participant removal', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_remaining_ops'), {
        type: 'group',
        groupName: 'Remaining Ops Test',
        participantIds: ['alice', 'charlie'], // Bob removed, Alice and Charlie remain
        adminIds: ['alice'],
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_remaining_ops', 'participants', 'charlie'), {
        id: 'charlie',
        name: 'Charlie Member',
        photoUrl: null,
        isOnline: true,
      });
    });
    const charlieDb = testEnv.authenticatedContext('charlie').firestore();
    // Charlie can read the conversation
    await assertSucceeds(
      getDoc(doc(charlieDb, 'conversations', 'group_remaining_ops'))
    );
    // Charlie can send a message
    await assertSucceeds(
      setDoc(doc(charlieDb, 'conversations', 'group_remaining_ops', 'messages', 'msg_charlie_1'), {
        senderId: 'charlie',
        senderName: 'Charlie Member',
        text: 'Hello team, still here!',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );
  });

  it('70. Normal non-admin member cannot remove anyone', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'conversations', 'group_non_admin_remove'), {
        type: 'group',
        groupName: 'Non Admin Guard',
        participantIds: ['alice', 'bob', 'charlie'],
        adminIds: ['alice'], // Bob is normal member
        createdBy: 'alice',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(context.firestore(), 'conversations', 'group_non_admin_remove', 'participants', 'charlie'), {
        id: 'charlie',
        name: 'Charlie',
        photoUrl: null,
        isOnline: false,
      });
    });
    const bobDb = testEnv.authenticatedContext('bob').firestore();
    // Bob attempts to remove Charlie via batch
    const batch = writeBatch(bobDb);
    batch.update(doc(bobDb, 'conversations', 'group_non_admin_remove'), {
      participantIds: ['alice', 'bob'],
    });
    batch.delete(doc(bobDb, 'conversations', 'group_non_admin_remove', 'participants', 'charlie'));
    await assertFails(batch.commit());
  });

  it('71. Existing direct conversation creation and operation remain unaffected', async () => {
    const aliceDb = testEnv.authenticatedContext('alice').firestore();
    const danDb = testEnv.authenticatedContext('dan').firestore();
    // Alice creates direct conversation with Dan ('alice' < 'dan' -> 'alice_dan')
    const batch = writeBatch(aliceDb);
    batch.set(doc(aliceDb, 'conversations', 'alice_dan'), {
      type: 'direct',
      participantIds: ['alice', 'dan'],
      createdBy: 'alice',
      createdAt: serverTimestamp(),
    });
    batch.set(doc(aliceDb, 'conversations', 'alice_dan', 'participants', 'alice'), {
      id: 'alice',
      name: 'Alice',
      photoUrl: null,
      isOnline: true,
    });
    batch.set(doc(aliceDb, 'conversations', 'alice_dan', 'participants', 'dan'), {
      id: 'dan',
      name: 'Dan',
      photoUrl: null,
      isOnline: false,
    });
    await assertSucceeds(batch.commit());

    // Dan can read and send message
    await assertSucceeds(
      getDoc(doc(danDb, 'conversations', 'alice_dan'))
    );
    await assertSucceeds(
      setDoc(doc(danDb, 'conversations', 'alice_dan', 'messages', 'direct_msg_unaffected'), {
        senderId: 'dan',
        text: 'Direct message working seamlessly',
        type: 'text',
        createdAt: serverTimestamp(),
      })
    );
  });
});
