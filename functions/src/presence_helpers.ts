/**
 * Guard against out-of-order execution of RTDB presence trigger invocations.
 *
 * If a newer RTDB state transition has already been committed to Firestore,
 * an older/stale invocation must not overwrite it.
 */
export function shouldProcessPresenceEvent(
  currentLastEventTimeMs: number,
  incomingEventTimeMs: number
): boolean {
  return incomingEventTimeMs >= currentLastEventTimeMs;
}
