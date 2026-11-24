import * as admin from 'firebase-admin';

export interface PresenceCommitDecision {
  canCommit: boolean;
  reason: 'newer_event' | 'stale_older' | 'stale_equal' | 'no_user_doc';
}

export interface HighPrecisionTimestamp {
  millis: number;
  micros: bigint;
  isoString: string;
}

export interface PresenceCommitParams {
  firestore: admin.firestore.Firestore;
  userId: string;
  isOnline: boolean;
  incomingTimestamp: HighPrecisionTimestamp;
  lastSeenTimestamp?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  onBeforeCommit?: () => Promise<void>;
}

export interface PresenceCommitResult {
  committed: boolean;
  reason: 'newer_event' | 'stale_older' | 'stale_equal' | 'no_user_doc';
  committedMicros?: bigint;
}

/**
 * Parses an event timestamp from RFC 3339 / ISO 8601 string, millisecond number, or microsecond number.
 * Preserves sub-millisecond (fractional second) precision up to microseconds.
 * Correctly normalizes timezone offsets (e.g. +02:00, -05:00) to UTC epoch microseconds.
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
    if (isNaN(raw) || !isFinite(raw)) {
      throw new Error(`Invalid timestamp number: ${raw}`);
    }
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
  // Regex to parse ISO 8601 / RFC 3339: e.g. 2026-11-21T18:42:15.123456Z or +02:00 or -05:00
  const match = str.match(/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})?$/i);

  if (!match) {
    const parsed = Date.parse(str);
    if (isNaN(parsed)) {
      throw new Error(`Invalid RFC 3339 / ISO 8601 timestamp: "${str}"`);
    }
    const ms = parsed;
    return {
      millis: ms,
      micros: BigInt(ms) * 1000n,
      isoString: new Date(ms).toISOString(),
    };
  }

  const dateTimePart = match[1];
  const fracDigits = match[2] || '0';
  const tzPart = match[3] || 'Z';

  // Construct ISO string with timezone offset to parse exact UTC second-level instant
  const baseIsoWithTz = `${dateTimePart}${tzPart}`;
  const parsedMs = Date.parse(baseIsoWithTz);
  if (isNaN(parsedMs)) {
    throw new Error(`Invalid RFC 3339 / ISO 8601 timestamp: "${str}"`);
  }

  const baseSeconds = Math.floor(parsedMs / 1000);
  // Normalize fractional seconds to 6 digits for microseconds
  const microsPart = fracDigits.padEnd(6, '0').slice(0, 6);
  const totalMicros = BigInt(baseSeconds) * 1000000n + BigInt(microsPart);
  const millis = Number(totalMicros / 1000n);

  // Normalized UTC ISO string representation
  const utcBaseIso = new Date(baseSeconds * 1000).toISOString().replace(/\.000Z$/, '');
  const normalizedIsoString = `${utcBaseIso}.${microsPart}Z`;

  return {
    millis,
    micros: totalMicros,
    isoString: normalizedIsoString,
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
 * Executes the authoritative presence mirror transaction against Firestore.
 * Production helper used by `onUserStatusChanged` and verified by concurrency tests.
 *
 * Guarantees:
 * - Reads `/users/{userId}` and `/public_users/{userId}` within a single transaction.
 * - Evaluates monotonicity via `evaluatePresenceCommit`.
 * - Atomically updates both documents if the event is newer.
 * - Discards older or duplicate events without state regression.
 */
export async function commitUserPresenceTransaction(
  params: PresenceCommitParams
): Promise<PresenceCommitResult> {
  const { firestore, userId, isOnline, incomingTimestamp, lastSeenTimestamp, onBeforeCommit } = params;
  const userDocRef = firestore.collection('users').doc(userId);
  const publicUserDocRef = firestore.collection('public_users').doc(userId);

  return await firestore.runTransaction(async (transaction) => {
    const [userDoc, publicUserDoc] = await Promise.all([
      transaction.get(userDocRef),
      transaction.get(publicUserDocRef),
    ]);

    if (!userDoc.exists && !publicUserDoc.exists) {
      return { committed: false, reason: 'no_user_doc' };
    }

    const userDocData = userDoc.data();
    const publicUserDocData = publicUserDoc.data();

    const userMicros = (userDocData?.presenceLastEventTimeMicros as number) || ((userDocData?.presenceLastEventTimeMs as number) || 0) * 1000;
    const publicMicros = (publicUserDocData?.presenceLastEventTimeMicros as number) || ((publicUserDocData?.presenceLastEventTimeMs as number) || 0) * 1000;
    const currentCommittedMicros = Math.max(userMicros, publicMicros);

    const decision = evaluatePresenceCommit(currentCommittedMicros, incomingTimestamp);
    if (!decision.canCommit) {
      return {
        committed: false,
        reason: decision.reason,
        committedMicros: BigInt(currentCommittedMicros),
      };
    }

    if (onBeforeCommit) {
      await onBeforeCommit();
    }

    const updateData: Record<string, any> = {
      isOnline,
      presenceLastEventTimeMs: incomingTimestamp.millis,
      presenceLastEventTimeMicros: Number(incomingTimestamp.micros),
      presenceLastEventTimeIso: incomingTimestamp.isoString,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!isOnline && lastSeenTimestamp) {
      updateData.lastSeen = lastSeenTimestamp;
    }

    if (userDoc.exists) {
      transaction.update(userDocRef, updateData);
    }
    if (publicUserDoc.exists) {
      transaction.update(publicUserDocRef, updateData);
    }

    return {
      committed: true,
      reason: decision.reason,
      committedMicros: incomingTimestamp.micros,
    };
  }, { maxAttempts: 25 });
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

/**
 * Max event age in milliseconds for presence events (5 minutes).
 */
export const MAX_PRESENCE_EVENT_AGE_MS = 5 * 60 * 1000;
