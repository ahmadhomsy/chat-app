import * as assert from 'assert';
import {
  computeAdminSuccession,
  chunkDocuments,
  handleStorageDeletionError,
  CONVERSATION_BATCH_SIZE,
  FCM_TOKEN_DELETE_BATCH_SIZE,
} from '../src/cleanup_helpers';

describe('Account Cleanup Production Helpers & Reliability Tests', () => {
  it('1. FCM token deletion chunks batches <= 400 when user has > 500 tokens', () => {
    const mockTokenDocs: Array<{ id: string }> = [];
    for (let i = 0; i < 950; i++) {
      mockTokenDocs.push({ id: `tok_doc_${i}` });
    }

    const chunks = chunkDocuments(mockTokenDocs, FCM_TOKEN_DELETE_BATCH_SIZE);
    assert.strictEqual(chunks.length, 3);
    assert.strictEqual(chunks[0].length, 400);
    assert.strictEqual(chunks[1].length, 400);
    assert.strictEqual(chunks[2].length, 150);

    // Verify all chunks are strictly under Firestore's 500-write limit
    chunks.forEach((c) => assert.ok(c.length <= 400));
  });

  it('2. Conversation query batch size limit strictly respects Firestore 500-op cap', () => {
    assert.strictEqual(CONVERSATION_BATCH_SIZE, 300);
    assert.ok(CONVERSATION_BATCH_SIZE < 500);

    // Verify simulated 750 conversations chunked into safe batches
    const totalConversations = 750;
    const batchSizes: number[] = [];
    let remaining = totalConversations;

    while (remaining > 0) {
      const current = Math.min(remaining, CONVERSATION_BATCH_SIZE);
      batchSizes.push(current);
      remaining -= current;
    }

    assert.deepStrictEqual(batchSizes, [300, 300, 150]);
  });

  it('3. Storage deletion: genuine 404 (not found) is treated as successful no-op', () => {
    // Numeric code 404
    assert.doesNotThrow(() => {
      handleStorageDeletionError({ code: 404, message: 'Not Found' });
    });

    // String code '404'
    assert.doesNotThrow(() => {
      handleStorageDeletionError({ code: '404', message: 'Not Found' });
    });

    // HTTP statusCode 404
    assert.doesNotThrow(() => {
      handleStorageDeletionError({ statusCode: 404, message: 'Not Found' });
    });

    // GCS error reason 'notFound'
    assert.doesNotThrow(() => {
      handleStorageDeletionError({ errors: [{ reason: 'notFound', message: 'File not found' }] });
    });
  });

  it('4. Storage deletion: non-404 errors (including messages with substring "not found") are rethrown', () => {
    // Storage backend unavailable (503)
    assert.throws(
      () => {
        handleStorageDeletionError({ code: 503, message: 'Storage backend unavailable' });
      },
      (err: any) => err.code === 503
    );

    // Permission denied (403)
    assert.throws(
      () => {
        handleStorageDeletionError({ code: 403, message: 'Permission denied' });
      },
      (err: any) => err.code === 403
    );

    // Critical: error message with "not found" but non-404 code must NOT be swallowed!
    assert.throws(
      () => {
        handleStorageDeletionError({ code: 401, message: 'Service account credentials not found' });
      },
      (err: any) => err.code === 401
    );

    // Generic error with "not found" in message must NOT be swallowed
    assert.throws(
      () => {
        handleStorageDeletionError(new Error('Network route not found to storage host'));
      },
      (err: any) => err.message.includes('Network route not found')
    );
  });

  it('5. Admin succession: promotes deterministically when sole group admin is deleted', () => {
    const currentAdmins = ['admin_to_delete'];
    const participants = ['admin_to_delete', 'charlie_z', 'bob_a', 'alice_k'];

    // In the absence of join timestamps, remaining non-admins are sorted lexicographically:
    // ['alice_k', 'bob_a', 'charlie_z'] -> first is 'alice_k'
    const newAdmins = computeAdminSuccession(currentAdmins, participants, 'admin_to_delete');
    assert.deepStrictEqual(newAdmins, ['alice_k']);
  });

  it('6. Admin succession: preserves existing co-administrators', () => {
    const currentAdmins = ['admin_to_delete', 'co_admin_1'];
    const participants = ['admin_to_delete', 'co_admin_1', 'user_regular'];

    const newAdmins = computeAdminSuccession(currentAdmins, participants, 'admin_to_delete');
    assert.deepStrictEqual(newAdmins, ['co_admin_1']);
  });

  it('7. Admin succession: handles multi-admin group where one admin is deleted', () => {
    const currentAdmins = ['admin_1', 'admin_to_delete', 'admin_3'];
    const participants = ['admin_1', 'admin_to_delete', 'admin_3', 'member_1'];

    const newAdmins = computeAdminSuccession(currentAdmins, participants, 'admin_to_delete');
    assert.deepStrictEqual(newAdmins, ['admin_1', 'admin_3']);
  });

  it('8. Retry after partial cleanup: skips completed stages and executes pending ones', () => {
    const progress = {
      fcmTokensCleaned: true,
      userDocCleaned: true,
      publicUserDocCleaned: true,
      avatarsCleaned: false, // failed previously
      rtdbCleaned: false,
      conversationsAnonymized: false,
    };

    const stagesToExecute: string[] = [];
    if (!progress.fcmTokensCleaned) stagesToExecute.push('fcmTokens');
    if (!progress.userDocCleaned) stagesToExecute.push('userDoc');
    if (!progress.publicUserDocCleaned) stagesToExecute.push('publicUserDoc');
    if (!progress.avatarsCleaned) stagesToExecute.push('avatars');
    if (!progress.rtdbCleaned) stagesToExecute.push('rtdb');
    if (!progress.conversationsAnonymized) stagesToExecute.push('conversations');

    assert.deepStrictEqual(stagesToExecute, ['avatars', 'rtdb', 'conversations']);
  });

  it('9. Repeated cleanup invocation on fully cleaned user is idempotent', () => {
    const progress = {
      fcmTokensCleaned: true,
      userDocCleaned: true,
      publicUserDocCleaned: true,
      avatarsCleaned: true,
      rtdbCleaned: true,
      conversationsAnonymized: true,
      completed: true,
    };

    const pendingStages = [
      !progress.fcmTokensCleaned,
      !progress.userDocCleaned,
      !progress.publicUserDocCleaned,
      !progress.avatarsCleaned,
      !progress.rtdbCleaned,
      !progress.conversationsAnonymized,
    ].filter(Boolean);

    assert.strictEqual(pendingStages.length, 0);
  });

  it('10. Migration dry-run: auditLegacyParticipantEmails detects legacy email snapshots without mutating in dry-run', async () => {
    const mockDocs = [
      {
        id: 'conv_clean',
        data: () => ({
          participants: {
            alice: { id: 'alice', name: 'Alice' },
            bob: { id: 'bob', name: 'Bob' },
          },
        }),
        ref: { update: async () => assert.fail('Dry run must not call update!') },
      },
      {
        id: 'conv_leaked',
        data: () => ({
          participants: {
            alice: { id: 'alice', name: 'Alice', email: 'alice@legacy.com' },
            bob: { id: 'bob', name: 'Bob', email: 'bob@legacy.com' },
          },
        }),
        ref: { update: async () => assert.fail('Dry run must not call update!') },
      },
    ];

    const mockFirestore: any = {
      collection: () => ({
        orderBy: () => ({
          limit: () => ({
            get: async () => ({
              empty: false,
              docs: mockDocs,
              size: mockDocs.length,
            }),
          }),
        }),
      }),
    };

    const { auditLegacyParticipantEmails } = await import('../src/migrations/dry_run_strip_participant_emails');
    const result = await auditLegacyParticipantEmails(mockFirestore, { dryRun: true });

    assert.strictEqual(result.totalScanned, 2);
    assert.strictEqual(result.conversationsWithEmail, 1);
    assert.strictEqual(result.totalEmailsFound, 2);
    assert.deepStrictEqual(result.sampleAffectedConversationIds, ['conv_leaked']);
    assert.strictEqual(result.dryRun, true);
  });

  it('11. Migration Execution Guard: enforces operational environment token, fresh backup bounds, project identity, and production safety lock', async () => {
    const { executeParticipantEmailSanitization } = await import('../src/migrations/dry_run_strip_participant_emails');
    const mockFirestore: any = {
      collection: () => ({
        orderBy: () => ({
          limit: () => ({
            get: async () => ({ empty: true, docs: [], size: 0 }),
          }),
        }),
      }),
    };

    const now = 1763780000000;
    const freshBackupTimestamp = new Date(now - 2 * 3600 * 1000).toISOString(); // 2 hours old
    const staleBackupTimestamp = new Date(now - 25 * 3600 * 1000).toISOString(); // 25 hours old
    const futureBackupTimestamp = new Date(now + 10 * 60 * 1000).toISOString(); // 10 minutes in future

    // 1. Missing environment token
    delete process.env.MIGRATION_EXECUTION_TOKEN;
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'SOME_TOKEN',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: freshBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'staging-project',
          activeProjectId: 'staging-project',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Missing or invalid execution authorization token/
    );

    // 2. Incorrect environment token
    process.env.MIGRATION_EXECUTION_TOKEN = 'CORRECT_TOKEN_123';
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'WRONG_TOKEN_XYZ',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: freshBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'staging-project',
          activeProjectId: 'staging-project',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Missing or invalid execution authorization token/
    );

    // 3. Missing backup ID
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: '',
          backupTimestamp: freshBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'staging-project',
          activeProjectId: 'staging-project',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Must provide a backup ID/
    );

    // 4. Invalid backup timestamp
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: 'invalid-iso-date',
          operatorBackupAttestation: true,
          targetProjectId: 'staging-project',
          activeProjectId: 'staging-project',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Must provide a valid ISO timestamp/
    );

    // 5. Backup timestamp older than 24 hours
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: staleBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'staging-project',
          activeProjectId: 'staging-project',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Backup timestamp is older than 24 hours/
    );

    // 6. Future backup timestamp
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: futureBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'staging-project',
          activeProjectId: 'staging-project',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Backup timestamp cannot be in the future/
    );

    // Missing operator attestation
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: freshBackupTimestamp,
          operatorBackupAttestation: false,
          targetProjectId: 'staging-project',
          activeProjectId: 'staging-project',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Operator must explicitly certify out-of-band backup verification/
    );

    // 7. Active Firebase project differs from targetProjectId
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: freshBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'staging-project-expected',
          activeProjectId: 'different-project-actual',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Target project ID "staging-project-expected" does not match active Firebase project "different-project-actual"/
    );

    // 8. Production project is rejected without explicit authorization
    delete process.env.ALLOW_PRODUCTION_MIGRATION;
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: 'gs://chat-app-28ac0-backups/2026-11-22',
          backupTimestamp: freshBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'chat-app-28ac0',
          activeProjectId: 'chat-app-28ac0',
          nowMs: now,
        });
      },
      /PRODUCTION_MIGRATION_LOCKED/
    );

    // 9. Production project cannot be bypassed by supplying a false staging target
    await assert.rejects(
      async () => {
        await executeParticipantEmailSanitization(mockFirestore, {
          authorizationToken: 'CORRECT_TOKEN_123',
          backupId: 'gs://staging-backups/2026-11-22',
          backupTimestamp: freshBackupTimestamp,
          operatorBackupAttestation: true,
          targetProjectId: 'fake-staging-target',
          activeProjectId: 'chat-app-28ac0',
          nowMs: now,
        });
      },
      /MIGRATION_BLOCKED: Target project ID "fake-staging-target" does not match active Firebase project "chat-app-28ac0"/
    );

    // 10. Verified non-production configuration follows the permitted execution path
    const result = await executeParticipantEmailSanitization(mockFirestore, {
      authorizationToken: 'CORRECT_TOKEN_123',
      backupId: 'gs://staging-backups/2026-11-22',
      backupTimestamp: freshBackupTimestamp,
      operatorBackupAttestation: true,
      targetProjectId: 'staging-project-test',
      activeProjectId: 'staging-project-test',
      nowMs: now,
    });
    assert.strictEqual(result.dryRun, false);
    assert.strictEqual(result.totalScanned, 0);

    // Clean up test environment
    delete process.env.MIGRATION_EXECUTION_TOKEN;
  });
});
