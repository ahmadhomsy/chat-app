import * as assert from 'assert';
import {
  evaluatePresenceCommit,
  shouldProcessPresenceEvent,
  computeIsOnlineFromConnections,
  parseEventTimestamp,
} from '../src/presence_helpers';

describe('Presence Ordering & Concurrency Guard Tests (Phase 4.2 & Phase 4.3 High-Precision)', () => {
  it('1. Event timestamps differing by milliseconds: newer commits, older is rejected', () => {
    const committedTime = '2026-11-21T18:42:15.100000Z';
    const newerTime = '2026-11-21T18:42:15.200000Z'; // 100ms newer

    const decision = evaluatePresenceCommit(committedTime, newerTime);
    assert.strictEqual(decision.canCommit, true);
    assert.strictEqual(decision.reason, 'newer_event');
    assert.strictEqual(shouldProcessPresenceEvent(committedTime, newerTime), true);

    const reverseDecision = evaluatePresenceCommit(newerTime, committedTime);
    assert.strictEqual(reverseDecision.canCommit, false);
    assert.strictEqual(reverseDecision.reason, 'stale_older');
    assert.strictEqual(shouldProcessPresenceEvent(newerTime, committedTime), false);
  });

  it('2. Event timestamps differing only by fractional milliseconds: high-precision ordering is preserved without collapsing', () => {
    // Both events share the exact same millisecond: 18:42:15.123
    // But eventB has 900 microseconds vs eventA having 100 microseconds (800 microseconds newer)
    const eventA = '2026-11-21T18:42:15.123100Z';
    const eventB = '2026-11-21T18:42:15.123900Z';

    const parsedA = parseEventTimestamp(eventA);
    const parsedB = parseEventTimestamp(eventB);

    assert.strictEqual(parsedA.millis, parsedB.millis); // Collapses in standard JS Date.getTime()
    assert.strictEqual(parsedB.micros > parsedA.micros, true); // Distinct in microsecond precision

    // Event B commits over Event A
    const decisionB = evaluatePresenceCommit(eventA, eventB);
    assert.strictEqual(decisionB.canCommit, true);
    assert.strictEqual(decisionB.reason, 'newer_event');

    // Event A cannot overwrite Event B (preventing sub-millisecond regressions)
    const decisionA = evaluatePresenceCommit(eventB, eventA);
    assert.strictEqual(decisionA.canCommit, false);
    assert.strictEqual(decisionA.reason, 'stale_older');
  });

  it('3. Equal timestamp handling: deterministically rejected as duplicate/stale_equal', () => {
    const committedTime = '2026-11-21T18:42:15.123456Z';
    const sameTime = '2026-11-21T18:42:15.123456Z';

    const decision = evaluatePresenceCommit(committedTime, sameTime);
    assert.strictEqual(decision.canCommit, false);
    assert.strictEqual(decision.reason, 'stale_equal');
    assert.strictEqual(shouldProcessPresenceEvent(committedTime, sameTime), false);
  });

  it('4. An older online event cannot overwrite a newer offline state', () => {
    const committedOfflineTime = '2026-11-21T18:42:20.000000Z';
    const delayedOnlineTime = '2026-11-21T18:42:15.000000Z'; // 5s older

    const decision = evaluatePresenceCommit(committedOfflineTime, delayedOnlineTime);
    assert.strictEqual(decision.canCommit, false);
    assert.strictEqual(decision.reason, 'stale_older');
  });

  it('5. An older offline event cannot overwrite a newer online state', () => {
    const committedOnlineTime = '2026-11-21T18:42:20.000000Z';
    const delayedOfflineTime = '2026-11-21T18:42:15.000000Z'; // 5s older

    const decision = evaluatePresenceCommit(committedOnlineTime, delayedOfflineTime);
    assert.strictEqual(decision.canCommit, false);
    assert.strictEqual(decision.reason, 'stale_older');
  });

  it('6. Two concurrent transaction attempts cannot produce a stale final state', () => {
    let committedState = {
      isOnline: false,
      timestamp: '2026-11-21T18:42:00.000000Z',
    };

    const txn1 = { timestamp: '2026-11-21T18:42:10.000500Z', isOnline: true };
    const txn2 = { timestamp: '2026-11-21T18:42:10.000100Z', isOnline: false }; // slightly older microsecond

    // Txn1 commits first
    const dec1 = evaluatePresenceCommit(committedState.timestamp, txn1.timestamp);
    assert.strictEqual(dec1.canCommit, true);
    committedState = { isOnline: txn1.isOnline, timestamp: txn1.timestamp };

    // Txn2 attempts to commit against the updated state
    const dec2 = evaluatePresenceCommit(committedState.timestamp, txn2.timestamp);
    assert.strictEqual(dec2.canCommit, false);
    assert.strictEqual(dec2.reason, 'stale_older');

    // Committed state remains Txn1's newer online state
    assert.strictEqual(committedState.isOnline, true);
    assert.strictEqual(committedState.timestamp, '2026-11-21T18:42:10.000500Z');
  });

  it('7. Multi-device presence remains correct', () => {
    // 3 active devices -> online
    assert.strictEqual(computeIsOnlineFromConnections(3), true);
    // 2 active devices -> online
    assert.strictEqual(computeIsOnlineFromConnections(2), true);
    // 1 active device left -> still online
    assert.strictEqual(computeIsOnlineFromConnections(1), true);
    // Final device disconnects -> offline
    assert.strictEqual(computeIsOnlineFromConnections(0), false);
  });

  it('8. Reconnection remains correct with newer timestamp', () => {
    let committedState = {
      isOnline: false,
      timestamp: '2026-11-21T18:42:20.000000Z',
    };

    const reconnectTime = '2026-11-21T18:42:30.000000Z'; // 10s after disconnect
    const reconnectDecision = evaluatePresenceCommit(committedState.timestamp, reconnectTime);
    assert.strictEqual(reconnectDecision.canCommit, true);

    committedState = {
      isOnline: true,
      timestamp: reconnectTime,
    };
    assert.strictEqual(committedState.isOnline, true);
    assert.strictEqual(committedState.timestamp, '2026-11-21T18:42:30.000000Z');
  });
});
