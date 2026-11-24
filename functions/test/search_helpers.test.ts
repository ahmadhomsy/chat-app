import * as assert from 'assert';
import {
  sanitizeSearchProfile,
  evaluateRollingRateLimit,
  enforceSearchRateLimit,
  MAX_SEARCH_REQUESTS_PER_MINUTE,
} from '../src/search_helpers';

describe('Search Rate Limiting & Privacy Helpers Tests (Phase 4.2 Rolling Window)', () => {
  it('1. sanitizeSearchProfile strictly excludes private email and security fields', () => {
    const rawUserData = {
      name: 'Alice Cooper',
      email: 'alice.cooper@private.com',
      provider: 'google',
      photoUrl: 'https://example.com/alice.png',
      isOnline: true,
      lastSeen: new Date('2026-11-21T12:00:00Z'),
      role: 'admin',
      fcmTokens: ['tok123'],
      status: 'active',
    };

    const sanitized = sanitizeSearchProfile('alice_uid', rawUserData);

    assert.strictEqual(sanitized.id, 'alice_uid');
    assert.strictEqual(sanitized.name, 'Alice Cooper');
    assert.strictEqual(sanitized.photoUrl, 'https://example.com/alice.png');
    assert.strictEqual(sanitized.isOnline, true);

    // Confirm email and sensitive fields are NOT exposed
    assert.strictEqual('email' in sanitized, false);
    assert.strictEqual('role' in sanitized, false);
    assert.strictEqual('fcmTokens' in sanitized, false);
    assert.strictEqual('provider' in sanitized, false);
    assert.strictEqual('status' in sanitized, false);
  });

  it('2. First 15 requests are accepted within the rolling window', () => {
    let timestamps: number[] = [];
    const baseTime = 1000000;

    for (let i = 0; i < 15; i++) {
      const res = evaluateRollingRateLimit(timestamps, baseTime + i * 1000);
      assert.strictEqual(res.allowed, true);
      timestamps = res.updatedTimestamps;
    }

    assert.strictEqual(timestamps.length, 15);
  });

  it('3. The 16th request within the rolling interval is rejected with resource-exhausted', () => {
    const baseTime = 1000000;
    // 15 existing requests spread across the last 30 seconds
    const existingTimestamps: number[] = [];
    for (let i = 0; i < 15; i++) {
      existingTimestamps.push(baseTime + i * 2000); // 0s to 28s
    }

    // 16th request at second 29 (inside 60s window)
    const res = evaluateRollingRateLimit(existingTimestamps, baseTime + 29000);
    assert.strictEqual(res.allowed, false);
    assert.ok(res.retryAfterSeconds && res.retryAfterSeconds > 0);
  });

  it('4. Expired request timestamps (> 60s old) are removed correctly', () => {
    const now = 2000000;
    // 10 expired timestamps from > 60s ago, 5 recent timestamps
    const oldTimestamps = [
      now - 90000,
      now - 80000,
      now - 70000,
      now - 65000,
    ];
    const recentTimestamps = [
      now - 30000,
      now - 20000,
      now - 10000,
    ];
    const allTimestamps = [...oldTimestamps, ...recentTimestamps];

    const res = evaluateRollingRateLimit(allTimestamps, now);
    assert.strictEqual(res.allowed, true);
    // Updated timestamps should only contain the 3 recent timestamps + the new one = 4
    assert.strictEqual(res.updatedTimestamps.length, 4);
    assert.strictEqual(res.updatedTimestamps.includes(now), true);
    oldTimestamps.forEach((t) => assert.strictEqual(res.updatedTimestamps.includes(t), false));
  });

  it('5. Requests around the 60-second boundary behave correctly without burst exploitation', () => {
    const baseTime = 1000000;
    // User made 15 requests at baseTime + 50s (e.g. 50s..55s)
    const timestamps: number[] = [];
    for (let i = 0; i < 15; i++) {
      timestamps.push(baseTime + 50000 + i * 100);
    }

    // At baseTime + 65s (only 15 seconds after the burst):
    // In a fixed-window counter, the minute 1..2 boundary would allow another 15.
    // In our rolling window, the previous 15 requests are still active (65s - 50s = 15s < 60s)!
    const burstAttempt = evaluateRollingRateLimit(timestamps, baseTime + 65000);
    assert.strictEqual(burstAttempt.allowed, false, 'Rolling limiter must prevent boundary bursts');

    // At baseTime + 111s (> 60s after the first burst request at 50s):
    // Old requests start expiring one by one
    const delayedAttempt = evaluateRollingRateLimit(timestamps, baseTime + 110101);
    assert.strictEqual(delayedAttempt.allowed, true, 'Requests older than 60s roll off');
  });

  it('6. enforceSearchRateLimit atomic transaction handles concurrent requests safely', async () => {
    let storedDoc: any = null;
    const mockFirestore: any = {
      collection: () => ({
        doc: () => ({}),
      }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async () => ({
            exists: storedDoc !== null,
            data: () => storedDoc,
          }),
          set: (_ref: any, data: any) => {
            storedDoc = { ...data };
          },
        };
        await fn(tx);
      },
    };

    const callerUid = 'user_concurrent';
    const now = 1000000;

    // Execute 15 sequential transactions
    for (let i = 0; i < MAX_SEARCH_REQUESTS_PER_MINUTE; i++) {
      await enforceSearchRateLimit(mockFirestore, callerUid, now + i * 500);
    }

    assert.strictEqual(storedDoc.timestamps.length, 15);

    // 16th transaction must throw resource-exhausted
    await assert.rejects(
      async () => {
        await enforceSearchRateLimit(mockFirestore, callerUid, now + 10000);
      },
      (err: any) => {
        assert.strictEqual(err.code, 'resource-exhausted');
        return true;
      }
    );
  });

  it('7. Window completely resets when no requests occurred in the last 60 seconds', () => {
    const baseTime = 1000000;
    const oldTimestamps = [baseTime, baseTime + 1000, baseTime + 2000];

    // Request 100 seconds later
    const res = evaluateRollingRateLimit(oldTimestamps, baseTime + 100000);
    assert.strictEqual(res.allowed, true);
    // All old timestamps dropped, only new timestamp exists
    assert.strictEqual(res.updatedTimestamps.length, 1);
    assert.strictEqual(res.updatedTimestamps[0], baseTime + 100000);
  });
});
