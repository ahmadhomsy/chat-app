import * as assert from 'assert';
import { shouldProcessPresenceEvent } from '../src/presence_helpers';

describe('Presence Ordering & Concurrency Guard Tests', () => {
  it('allows incoming event when incoming timestamp is newer than committed state', () => {
    const committedTime = 1700000000000;
    const incomingTime = 1700000005000; // 5s newer

    const allowed = shouldProcessPresenceEvent(committedTime, incomingTime);
    assert.strictEqual(allowed, true);
  });

  it('rejects stale incoming event when a newer transition was already committed', () => {
    const committedTime = 1700000010000; // newer transition committed first
    const incomingTime = 1700000002000; // delayed older transition

    const allowed = shouldProcessPresenceEvent(committedTime, incomingTime);
    assert.strictEqual(allowed, false);
  });

  it('allows event with equal timestamp (concurrent or idempotently retried)', () => {
    const committedTime = 1700000000000;
    const incomingTime = 1700000000000;

    const allowed = shouldProcessPresenceEvent(committedTime, incomingTime);
    assert.strictEqual(allowed, true);
  });
});
