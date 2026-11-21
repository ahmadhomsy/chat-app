export interface PresenceCommitDecision {
  canCommit: boolean;
  reason: 'newer_event' | 'stale_older' | 'stale_equal' | 'no_user_doc';
}

export interface HighPrecisionTimestamp {
  millis: number;
  micros: bigint;
  isoString: string;
}

/**
 * Parses an event timestamp from RFC 3339 / ISO 8601 string, millisecond number, or microsecond number.
 * Preserves sub-millisecond (fractional second) precision up to microseconds.
 */
export function parseEventTimestamp(raw: string | number | undefined | null): HighPrecisionTimestamp {
  if (raw === undefined || raw === null) {
    const now = Date.now();
    return {
      millis: now,
      micros: BigInt(now) * 1000n,
      isoString: new Date(now).toISOString(),
    };
  }

  if (typeof raw === 'number') {
    // If number is already in microsecond range (> 1e14), treat as micros
    if (raw > 1e14) {
      const micros = BigInt(Math.floor(raw));
      const millis = Number(micros / 1000n);
      return {
        millis,
        micros,
        isoString: new Date(millis).toISOString(),
      };
    }
    const ms = Math.floor(raw);
    return {
      millis: ms,
      micros: BigInt(ms) * 1000n,
      isoString: new Date(ms).toISOString(),
    };
  }

  const str = raw.trim();
  // Regex to parse ISO 8601 / RFC 3339: e.g. 2026-11-21T18:42:15.123456Z
  const match = str.match(/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})?$/);

  if (!match) {
    const parsed = Date.parse(str);
    const ms = isNaN(parsed) ? Date.now() : parsed;
    return {
      millis: ms,
      micros: BigInt(ms) * 1000n,
      isoString: new Date(ms).toISOString(),
    };
  }

  const baseIso = `${match[1]}Z`;
  const baseSeconds = Math.floor(Date.parse(baseIso) / 1000);
  const fracDigits = match[2] || '0';
  // Normalize fractional seconds to 6 digits for microseconds
  const microsPart = fracDigits.padEnd(6, '0').slice(0, 6);
  const totalMicros = BigInt(baseSeconds) * 1000000n + BigInt(microsPart);
  const millis = Number(totalMicros / 1000n);

  return {
    millis,
    micros: totalMicros,
    isoString: str,
  };
}

/**
 * Evaluates whether an incoming RTDB presence transition is authorized to commit
 * given committed and incoming timestamps.
 *
 * Strict Ordering Semantics:
 * - High-precision comparison: uses microseconds to avoid collapsing distinct events
 *   occurring within the same millisecond.
 * - Only strictly newer events (incoming > committed) can commit.
 * - Older events (incoming < committed) are dropped as stale_older.
 * - Equal timestamps (incoming === committed) are dropped deterministically as stale_equal.
 */
export function evaluatePresenceCommit(
  committed: HighPrecisionTimestamp | string | number,
  incoming: HighPrecisionTimestamp | string | number
): PresenceCommitDecision {
  const comm = typeof committed === 'object' && committed !== null && 'micros' in committed
    ? committed
    : parseEventTimestamp(committed);

  const inc = typeof incoming === 'object' && incoming !== null && 'micros' in incoming
    ? incoming
    : parseEventTimestamp(incoming);

  if (inc.micros > comm.micros) {
    return { canCommit: true, reason: 'newer_event' };
  }
  if (inc.micros === comm.micros) {
    return { canCommit: false, reason: 'stale_equal' };
  }
  return { canCommit: false, reason: 'stale_older' };
}

/**
 * Backward-compatible helper that enforces strict monotonicity.
 */
export function shouldProcessPresenceEvent(
  currentLastEventTime: string | number,
  incomingEventTime: string | number
): boolean {
  return evaluatePresenceCommit(currentLastEventTime, incomingEventTime).canCommit;
}

/**
 * Evaluates connection count to determine online status.
 * Multiple devices: user is online if connections > 0.
 */
export function computeIsOnlineFromConnections(connectionCount: number): boolean {
  return connectionCount > 0;
}
