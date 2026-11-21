import * as assert from 'assert';
import {
  evaluatePresenceCommit,
  shouldProcessPresenceEvent,
  computeIsOnlineFromConnections,
} from '../src/presence_helpers';

describe('Presence Ordering & Concurrency Guard Tests (Phase 4.2)', () => {
  it('1. Newer connect event commits', () => {
    const committedTime = 1700000000000;
    const incomingConnectTime = 1700000005000; // 5s newer

    const decision = evaluatePresenceCommit(committedTime, incomingConnectTime);
    assert.strictEqual(decision.canCommit, true);
    assert.strictEqual(decision.reason, 'newer_event');
    assert.strictEqual(shouldProcessPresenceEvent(committedTime, incomingConnectTime), true);
  });

  it('2. Older disconnect event cannot overwrite the newer state', () => {
    const committedNewerOnlineTime = 1700000010000;
    const incomingDelayedDisconnectTime = 1700000005000; // 5s older

    const decision = evaluatePresenceCommit(committedNewerOnlineTime, incomingDelayedDisconnectTime);
    assert.strictEqual(decision.canCommit, false);
    assert.strictEqual(decision.reason, 'stale_older');
    assert.strictEqual(shouldProcessPresenceEvent(committedNewerOnlineTime, incomingDelayedDisconnectTime), false);
  });

  it('3. Newer disconnect event commits', () => {
    const committedOnlineTime = 1700000010000;
    const incomingDisconnectTime = 1700000020000; // 10s newer

    const decision = evaluatePresenceCommit(committedOnlineTime, incomingDisconnectTime);
    assert.strictEqual(decision.canCommit, true);
    assert.strictEqual(decision.reason, 'newer_event');
  });

  it('4. Older connect event cannot overwrite the newer offline state', () => {
    const committedOfflineTime = 1700000020000;
    const incomingDelayedConnectTime = 1700000015000; // 5s older

    const decision = evaluatePresenceCommit(committedOfflineTime, incomingDelayedConnectTime);
    assert.strictEqual(decision.canCommit, false);
    assert.strictEqual(decision.reason, 'stale_older');
  });

  it('5. Two simultaneous transitions: the first to commit establishes timestamp; the second with older/equal time is rejected', () => {
    let committedState = {
      isOnline: false,
      presenceLastEventTimeMs: 1700000000000,
    };

    const eventA = { time: 1700000005000, isOnline: true };
    const eventB = { time: 1700000004000, isOnline: false }; // arrived concurrently, but slightly older timestamp

    // Simulated transaction for Event A:
    const decisionA = evaluatePresenceCommit(committedState.presenceLastEventTimeMs, eventA.time);
    assert.strictEqual(decisionA.canCommit, true);
    committedState = { isOnline: eventA.isOnline, presenceLastEventTimeMs: eventA.time };

    // Simulated transaction for Event B (competing concurrent transaction):
    // Inside transaction, it reads the updated committedState:
    const decisionB = evaluatePresenceCommit(committedState.presenceLastEventTimeMs, eventB.time);
    assert.strictEqual(decisionB.canCommit, false);
    assert.strictEqual(decisionB.reason, 'stale_older');

    // State remains Event A's newer online state
    assert.strictEqual(committedState.isOnline, true);
    assert.strictEqual(committedState.presenceLastEventTimeMs, 1700000005000);
  });

  it('6. Multiple devices: user remains online while at least one connection exists', () => {
    // 3 active devices
    assert.strictEqual(computeIsOnlineFromConnections(3), true);
    // 2 active devices
    assert.strictEqual(computeIsOnlineFromConnections(2), true);
    // 1 active device left
    assert.strictEqual(computeIsOnlineFromConnections(1), true);
    // Final device disconnects -> offline
    assert.strictEqual(computeIsOnlineFromConnections(0), false);
  });

  it('7. Reconnection restores the correct online state with newer timestamp', () => {
    let committedState = {
      isOnline: false,
      presenceLastEventTimeMs: 1700000020000,
    };

    const reconnectTime = 1700000030000; // 10s after disconnect
    const reconnectDecision = evaluatePresenceCommit(committedState.presenceLastEventTimeMs, reconnectTime);
    assert.strictEqual(reconnectDecision.canCommit, true);

    committedState = {
      isOnline: true,
      presenceLastEventTimeMs: reconnectTime,
    };
    assert.strictEqual(committedState.isOnline, true);
    assert.strictEqual(committedState.presenceLastEventTimeMs, 1700000030000);
  });

  it('8. Equal or indistinguishable timestamps are handled deterministically without overwriting committed state', () => {
    const committedTime = 1700000050000;
    const sameTimeEvent = 1700000050000; // exact same millisecond

    const decision = evaluatePresenceCommit(committedTime, sameTimeEvent);
    // Deterministic policy: once a state is committed for timestamp T, another event with equal timestamp T CANNOT overwrite
    assert.strictEqual(decision.canCommit, false);
    assert.strictEqual(decision.reason, 'stale_equal');
    assert.strictEqual(shouldProcessPresenceEvent(committedTime, sameTimeEvent), false);
  });
});
