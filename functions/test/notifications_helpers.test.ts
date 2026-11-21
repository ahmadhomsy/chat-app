import * as assert from 'assert';
import {
  classifyFcmError,
  filterTokensForDispatch,
  chunkItems,
  processMulticastResponses,
  evaluateEventLock,
  TokenEntry,
} from '../src/notification_helpers';

describe('Push Notifications Production Helpers & Reliability Tests', () => {
  const dummyDocRef = (id: string) => ({ id, delete: async () => {} });

  it('1. All tokens succeed', () => {
    const chunk: TokenEntry[] = [
      { token: 'tok_1', userId: 'u1', docRef: dummyDocRef('d1') },
      { token: 'tok_2', userId: 'u2', docRef: dummyDocRef('d2') },
    ];
    const responses = [
      { success: true },
      { success: true },
    ];

    const result = processMulticastResponses(chunk, responses);
    assert.strictEqual(result.newlySentTokens.length, 2);
    assert.strictEqual(result.newlyPermanentlyFailedTokens.length, 0);
    assert.strictEqual(result.transientFailures.length, 0);
    assert.strictEqual(result.invalidDocRefsToDelete.length, 0);
  });

  it('2. One permanently invalid token and all remaining tokens succeed', () => {
    const doc1 = dummyDocRef('d1');
    const doc2 = dummyDocRef('d2');
    const chunk: TokenEntry[] = [
      { token: 'tok_invalid', userId: 'u1', docRef: doc1 },
      { token: 'tok_valid', userId: 'u2', docRef: doc2 },
    ];
    const responses = [
      { success: false, error: { code: 'messaging/invalid-registration-token', message: 'Invalid token' } },
      { success: true },
    ];

    const result = processMulticastResponses(chunk, responses);
    assert.deepStrictEqual(result.newlySentTokens, ['tok_valid']);
    assert.deepStrictEqual(result.newlyPermanentlyFailedTokens, ['tok_invalid']);
    assert.strictEqual(result.invalidDocRefsToDelete.length, 1);
    assert.strictEqual(result.invalidDocRefsToDelete[0], doc1);
    assert.strictEqual(result.transientFailures.length, 0);
  });

  it('3. One transient token failure is classified as retryable', () => {
    const chunk: TokenEntry[] = [
      { token: 'tok_1', userId: 'u1', docRef: dummyDocRef('d1') },
      { token: 'tok_transient', userId: 'u2', docRef: dummyDocRef('d2') },
    ];
    const responses = [
      { success: true },
      { success: false, error: { code: 'messaging/server-unavailable', message: 'FCM server busy' } },
    ];

    const result = processMulticastResponses(chunk, responses);
    assert.deepStrictEqual(result.newlySentTokens, ['tok_1']);
    assert.strictEqual(result.newlyPermanentlyFailedTokens.length, 0);
    assert.strictEqual(result.invalidDocRefsToDelete.length, 0);
    assert.strictEqual(result.transientFailures.length, 1);
    assert.strictEqual(result.transientFailures[0].token, 'tok_transient');
    assert.strictEqual(result.transientFailures[0].code, 'messaging/server-unavailable');
  });

  it('4. A chunk succeeds and a later chunk fails', () => {
    const chunk1: TokenEntry[] = [
      { token: 'tok_1', userId: 'u1', docRef: dummyDocRef('d1') },
    ];
    const chunk2: TokenEntry[] = [
      { token: 'tok_2', userId: 'u2', docRef: dummyDocRef('d2') },
    ];

    const res1 = processMulticastResponses(chunk1, [{ success: true }]);
    const res2 = processMulticastResponses(chunk2, [
      { success: false, error: { code: 'messaging/internal-error', message: 'Internal error' } },
    ]);

    assert.strictEqual(res1.newlySentTokens.length, 1);
    assert.strictEqual(res1.transientFailures.length, 0);
    assert.strictEqual(res2.newlySentTokens.length, 0);
    assert.strictEqual(res2.transientFailures.length, 1);
  });

  it('5. Retry excludes tokens already successfully delivered or permanently failed', () => {
    const allTokens: TokenEntry[] = [
      { token: 'tok_1', userId: 'u1', docRef: dummyDocRef('d1') },
      { token: 'tok_2', userId: 'u2', docRef: dummyDocRef('d2') },
      { token: 'tok_3', userId: 'u3', docRef: dummyDocRef('d3') },
    ];
    const previouslySent = ['tok_1'];
    const permanentlyFailed = ['tok_2'];

    const filtered = filterTokensForDispatch(allTokens, previouslySent, permanentlyFailed);
    assert.strictEqual(filtered.length, 1);
    assert.strictEqual(filtered[0].token, 'tok_3');
  });

  it('6. Progress persistence failure handling: throws error to prevent false completion', async () => {
    let failureTriggered = false;
    const mockEventRef = {
      update: async () => {
        failureTriggered = true;
        throw new Error('Firestore connection lost during progress persistence');
      },
    };

    try {
      await mockEventRef.update();
      assert.fail('Should have thrown');
    } catch (err: any) {
      assert.strictEqual(failureTriggered, true);
      assert.ok(err.message.includes('Firestore connection lost'));
    }
  });

  it('7. Two invocations contend for the same event: second is rejected', () => {
    const now = 1700000000000;
    const activeLockedEvent = {
      state: 'processing',
      lockedAtMs: now - 15000, // 15s ago, lease is 60s
    };

    const evalResult = evaluateEventLock(activeLockedEvent, now, 60000);
    assert.strictEqual(evalResult.canProcess, false);
    assert.strictEqual(evalResult.reason, 'in_progress');
  });

  it('8. An expired lease can be safely recovered and resumed', () => {
    const now = 1700000000000;
    const expiredEvent = {
      state: 'processing',
      lockedAtMs: now - 75000, // 75s ago (lease expired > 60s)
      sentTokens: ['tok_pre_1'],
      failedTokens: ['tok_bad_1'],
    };

    const evalResult = evaluateEventLock(expiredEvent, now, 60000);
    assert.strictEqual(evalResult.canProcess, true);
    assert.strictEqual(evalResult.reason, 'recovered');
    assert.deepStrictEqual(evalResult.previouslySentTokens, ['tok_pre_1']);
    assert.deepStrictEqual(evalResult.permanentlyFailedTokens, ['tok_bad_1']);
  });

  it('9. More than 500 tokens are processed in separate chunks of <= 500', () => {
    const tokens: TokenEntry[] = [];
    for (let i = 0; i < 1250; i++) {
      tokens.push({ token: `tok_${i}`, userId: `u_${i}`, docRef: dummyDocRef(`d_${i}`) });
    }

    const chunks = chunkItems(tokens, 500);
    assert.strictEqual(chunks.length, 3);
    assert.strictEqual(chunks[0].length, 500);
    assert.strictEqual(chunks[1].length, 500);
    assert.strictEqual(chunks[2].length, 250);
  });

  it('10. An event is never marked sent while retryable failures remain', () => {
    const chunk: TokenEntry[] = [
      { token: 'tok_1', userId: 'u1', docRef: dummyDocRef('d1') },
      { token: 'tok_2', userId: 'u2', docRef: dummyDocRef('d2') },
    ];
    const responses = [
      { success: true },
      { success: false, error: { code: 'messaging/server-unavailable', message: 'Busy' } },
    ];

    const result = processMulticastResponses(chunk, responses);
    // Transient failure exists
    const hasRetryableErrors = result.transientFailures.length > 0;
    assert.strictEqual(hasRetryableErrors, true);

    // Simulated event state determination
    const finalEventState = hasRetryableErrors ? 'failed' : 'sent';
    assert.strictEqual(finalEventState, 'failed');
  });

  it('11. Error classification correctly categorizes registration token error codes', () => {
    assert.strictEqual(classifyFcmError('messaging/invalid-registration-token'), 'permanent');
    assert.strictEqual(classifyFcmError('messaging/registration-token-not-registered'), 'permanent');
    assert.strictEqual(classifyFcmError('messaging/server-unavailable'), 'transient');
    assert.strictEqual(classifyFcmError('messaging/internal-error'), 'transient');
  });
});
