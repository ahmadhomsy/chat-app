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

  describe('RFC 3339 Timezone Offset Normalization Tests (Section 7)', () => {
    it('9. UTC timestamp parses correctly and preserves microseconds', () => {
      const utcIso = '2026-11-21T18:42:15.123456Z';
      const parsed = parseEventTimestamp(utcIso);

      assert.strictEqual(parsed.isoString, utcIso);
      assert.strictEqual(typeof parsed.millis, 'number');
      assert.strictEqual(typeof parsed.micros, 'bigint');
      // Microsecond part matches 123456
      assert.strictEqual(Number(parsed.micros % 1000000n), 123456);
    });

    it('10. Same instant represented with positive timezone offset produces identical microsecond timestamp', () => {
      // 20:42:15 in UTC+02:00 is exactly 18:42:15 UTC
      const utcInstant = '2026-11-21T18:42:15.123456Z';
      const positiveOffsetInstant = '2026-11-21T20:42:15.123456+02:00';

      const parsedUtc = parseEventTimestamp(utcInstant);
      const parsedPositive = parseEventTimestamp(positiveOffsetInstant);

      assert.strictEqual(parsedPositive.micros, parsedUtc.micros);
      assert.strictEqual(parsedPositive.millis, parsedUtc.millis);
      assert.strictEqual(parsedPositive.isoString, utcInstant);
    });

    it('11. Same instant represented with negative timezone offset produces identical microsecond timestamp', () => {
      // 13:42:15 in UTC-05:00 is exactly 18:42:15 UTC
      const utcInstant = '2026-11-21T18:42:15.123456Z';
      const negativeOffsetInstant = '2026-11-21T13:42:15.123456-05:00';

      const parsedUtc = parseEventTimestamp(utcInstant);
      const parsedNegative = parseEventTimestamp(negativeOffsetInstant);

      assert.strictEqual(parsedNegative.micros, parsedUtc.micros);
      assert.strictEqual(parsedNegative.millis, parsedUtc.millis);
      assert.strictEqual(parsedNegative.isoString, utcInstant);
    });

    it('12. Fractional seconds are padded or trimmed to 6 digits (microsecond precision)', () => {
      // 3 fractional digits -> padded to microseconds
      const shortFrac = '2026-11-21T18:42:15.123Z';
      const parsedShort = parseEventTimestamp(shortFrac);
      assert.strictEqual(Number(parsedShort.micros % 1000000n), 123000);

      // 9 fractional digits -> truncated to 6 digits (microseconds, without claiming nanosecond support)
      const longFrac = '2026-11-21T18:42:15.123456789Z';
      const parsedLong = parseEventTimestamp(longFrac);
      assert.strictEqual(Number(parsedLong.micros % 1000000n), 123456);
      assert.strictEqual(parsedLong.isoString, '2026-11-21T18:42:15.123456Z');
    });

    it('13. Invalid input follows documented safe behavior (throws descriptive Error)', () => {
      assert.throws(
        () => parseEventTimestamp('completely-invalid-date-string'),
        /Invalid RFC 3339 \/ ISO 8601 timestamp/
      );
      assert.throws(
        () => parseEventTimestamp(NaN),
        /Invalid timestamp number/
      );
      assert.throws(
        () => parseEventTimestamp(Infinity),
        /Invalid timestamp number/
      );
    });
  });
});
