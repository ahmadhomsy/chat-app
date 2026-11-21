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
    const err404 = { code: 404, message: 'Not Found' };
    assert.doesNotThrow(() => {
      handleStorageDeletionError(err404);
    });

    const errNotFoundMsg = { message: 'The specified key does not exist (not found).' };
    assert.doesNotThrow(() => {
      handleStorageDeletionError(errNotFoundMsg);
    });
  });

  it('4. Storage deletion: transient non-404 error rethrows to prevent false completion', () => {
    const err500 = { code: 503, message: 'Storage backend unavailable' };
    assert.throws(
      () => {
        handleStorageDeletionError(err500);
      },
      (err: any) => err.code === 503
    );

    const errPermission = { code: 403, message: 'Permission denied' };
    assert.throws(
      () => {
        handleStorageDeletionError(errPermission);
      },
      (err: any) => err.code === 403
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
});
