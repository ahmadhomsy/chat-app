import * as assert from 'assert';
import {
  sanitizeSearchProfile,
  enforceSearchRateLimit,
  MAX_SEARCH_REQUESTS_PER_MINUTE,
} from '../src/search_helpers';

describe('Search Rate Limiting & Privacy Helpers Tests', () => {
  it('sanitizeSearchProfile strictly excludes private email and security fields', () => {
    const rawUserData = {
      name: 'Alice Cooper',
      email: 'alice.cooper@private.com',
      provider: 'google',
      photoUrl: 'https://example.com/alice.png',
      isOnline: true,
      lastSeen: { toDate: () => new Date('2026-11-21T12:00:00Z') },
      role: 'admin',
      fcmTokens: ['tok123'],
      status: 'active',
    };

    const sanitized = sanitizeSearchProfile('alice_uid', rawUserData);

    assert.strictEqual(sanitized.id, 'alice_uid');
    assert.strictEqual(sanitized.name, 'Alice Cooper');
    assert.strictEqual(sanitized.photoUrl, 'https://example.com/alice.png');
    assert.strictEqual(sanitized.isOnline, true);
    assert.strictEqual(sanitized.lastSeen, '2026-11-21T12:00:00.000Z');

    // Confirm email and sensitive fields are NOT exposed
    assert.strictEqual('email' in sanitized, false);
    assert.strictEqual('role' in sanitized, false);
    assert.strictEqual('fcmTokens' in sanitized, false);
    assert.strictEqual('provider' in sanitized, false);
    assert.strictEqual('status' in sanitized, false);
  });

  it('enforceSearchRateLimit increments counter within active window', async () => {
    let storedData: any = null;
    const mockFirestore: any = {
      collection: () => ({
        doc: () => ({
          // Mock DocumentReference
        }),
      }),
      runTransaction: async (updateFunction: any) => {
        const mockTransaction = {
          get: async () => ({
            exists: storedData !== null,
            data: () => storedData,
          }),
          set: (_ref: any, data: any) => {
            storedData = { ...data };
          },
          update: (_ref: any, data: any) => {
            if (data.count && typeof data.count === 'object') {
              storedData.count = (storedData.count || 0) + 1;
            } else {
              storedData = { ...storedData, ...data };
            }
          },
        };
        await updateFunction(mockTransaction);
      },
    };

    const callerUid = 'user_rate_1';
    const now = 1000000;

    // 1st request -> sets count: 1
    await enforceSearchRateLimit(mockFirestore, callerUid, now);
    assert.strictEqual(storedData.count, 1);

    // 2nd request -> increments count to 2
    await enforceSearchRateLimit(mockFirestore, callerUid, now + 1000);
    assert.strictEqual(storedData.count, 2);
  });

  it('enforceSearchRateLimit throws resource-exhausted when request count exceeds limit', async () => {
    let storedData: any = {
      count: MAX_SEARCH_REQUESTS_PER_MINUTE,
      windowStartMs: 1000000,
    };

    const mockFirestore: any = {
      collection: () => ({ doc: () => ({}) }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async () => ({ exists: true, data: () => storedData }),
          set: (_r: any, d: any) => { storedData = d; },
          update: (_r: any, d: any) => { storedData = { ...storedData, ...d }; },
        };
        await fn(tx);
      },
    };

    await assert.rejects(
      async () => {
        await enforceSearchRateLimit(mockFirestore, 'user_rate_2', 1000000 + 10000); // 10s into window
      },
      (err: any) => {
        assert.strictEqual(err.code, 'resource-exhausted');
        return true;
      }
    );
  });

  it('enforceSearchRateLimit resets counter when rolling window expires', async () => {
    let storedData: any = {
      count: MAX_SEARCH_REQUESTS_PER_MINUTE,
      windowStartMs: 1000000,
    };

    const mockFirestore: any = {
      collection: () => ({ doc: () => ({}) }),
      runTransaction: async (fn: any) => {
        const tx = {
          get: async () => ({ exists: true, data: () => storedData }),
          set: (_r: any, d: any) => { storedData = d; },
          update: (_r: any, d: any) => { storedData = { ...storedData, ...d }; },
        };
        await fn(tx);
      },
    };

    // 65 seconds later (> 60s window)
    await enforceSearchRateLimit(mockFirestore, 'user_rate_2', 1000000 + 65000);
    assert.strictEqual(storedData.count, 1);
  });
});
