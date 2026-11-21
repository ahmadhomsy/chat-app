export interface PresenceCommitDecision {
  canCommit: boolean;
  reason: 'newer_event' | 'stale_older' | 'stale_equal' | 'no_user_doc';
}

/**
 * Evaluates whether an incoming RTDB presence transition is authorized to commit
 * to Firestore given the currently committed version in the database.
 *
 * Strict Ordering Semantics:
 * - Only strictly newer events (incomingEventTimeMs > committedLastEventTimeMs) can commit new state.
 * - Older events (incomingEventTimeMs < committedLastEventTimeMs) are dropped as stale.
 * - Equal timestamps (incomingEventTimeMs === committedLastEventTimeMs) are dropped deterministically
 *   to prevent race conditions from overwriting already-committed state at the same millisecond.
 */
export function evaluatePresenceCommit(
  committedLastEventTimeMs: number,
  incomingEventTimeMs: number
): PresenceCommitDecision {
  if (incomingEventTimeMs > committedLastEventTimeMs) {
    return { canCommit: true, reason: 'newer_event' };
  }
  if (incomingEventTimeMs === committedLastEventTimeMs) {
    return { canCommit: false, reason: 'stale_equal' };
  }
  return { canCommit: false, reason: 'stale_older' };
}

/**
 * Backward-compatible helper that enforces strict monotonicity.
 */
export function shouldProcessPresenceEvent(
  currentLastEventTimeMs: number,
  incomingEventTimeMs: number
): boolean {
  return incomingEventTimeMs > currentLastEventTimeMs;
}

/**
 * Evaluates connection count to determine online status.
 * Multiple devices: user is online if connections > 0.
 */
export function computeIsOnlineFromConnections(connectionCount: number): boolean {
  return connectionCount > 0;
}
