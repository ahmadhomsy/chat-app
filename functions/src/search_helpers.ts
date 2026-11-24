import * as admin from 'firebase-admin';

export const MAX_SEARCH_REQUESTS_PER_MINUTE = 15;
export const RATE_LIMIT_WINDOW_MS = 60 * 1000;

export interface RollingRateLimitRecord {
  timestamps: number[];
  expiresAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.FieldValue;
}

/**
 * Pure evaluation helper for rolling rate limit window.
 * Filters out timestamps older than (nowMs - windowMs), checks if count >= maxRequests,
 * and if allowed, appends nowMs to the active timestamps.
 */
export function evaluateRollingRateLimit(
  existingTimestamps: number[],
  nowMs: number,
  maxRequests: number = MAX_SEARCH_REQUESTS_PER_MINUTE,
  windowMs: number = RATE_LIMIT_WINDOW_MS
): { allowed: boolean; updatedTimestamps: number[]; retryAfterSeconds?: number } {
  const cutoff = nowMs - windowMs;
  const activeTimestamps = existingTimestamps.filter((t) => typeof t === 'number' && t > cutoff);

  if (activeTimestamps.length >= maxRequests) {
    const oldest = activeTimestamps[0];
    const retryAfterSeconds = Math.max(1, Math.ceil((windowMs - (nowMs - oldest)) / 1000));
    return {
      allowed: false,
      updatedTimestamps: activeTimestamps,
      retryAfterSeconds,
    };
  }

  activeTimestamps.push(nowMs);
  return {
    allowed: true,
    updatedTimestamps: activeTimestamps,
  };
}

/**
 * Checks and updates the atomic, shared per-user search rate limit stored in Firestore `_rate_limits`.
 * Implements a strict rolling 60-second window with max 15 requests per minute.
 * Concurrent requests are serialized via Firestore transaction on `_rate_limits/{callerUid}`.
 * Throws an error with code 'resource-exhausted' if the limit is exceeded.
 */
export async function enforceSearchRateLimit(
  firestore: admin.firestore.Firestore,
  callerUid: string,
  nowMs: number = Date.now(),
  maxRequests: number = MAX_SEARCH_REQUESTS_PER_MINUTE,
  windowMs: number = RATE_LIMIT_WINDOW_MS
): Promise<void> {
  const rateLimitRef = firestore.collection('_rate_limits').doc(callerUid);

  await firestore.runTransaction(async (transaction) => {
    const doc = await transaction.get(rateLimitRef);
    const existingTimestamps: number[] = doc.exists && Array.isArray(doc.data()?.timestamps)
      ? doc.data()!.timestamps
      : [];

    const result = evaluateRollingRateLimit(existingTimestamps, nowMs, maxRequests, windowMs);

    if (!result.allowed) {
      const error = new Error(
        `Search rate limit exceeded. Please wait ${result.retryAfterSeconds} second(s) before searching again.`
      );
      (error as any).code = 'resource-exhausted';
      (error as any).retryAfterSeconds = result.retryAfterSeconds;
      throw error;
    }

    // TTL set to 7 days from now
    const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + 7 * 24 * 60 * 60 * 1000);

    transaction.set(
      rateLimitRef,
      {
        timestamps: result.updatedTimestamps,
        expiresAt,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }, { maxAttempts: 25 });
}

/**
 * Strips private user data and produces only approved public discovery fields.
 * PRIVACY REMEDIATION (Phase 4.1):
 * Email addresses and private security metadata are strictly excluded.
 */
export function sanitizeSearchProfile(userId: string, userData: admin.firestore.DocumentData) {
  return {
    id: userId,
    name: (userData.name as string) || 'User',
    photoUrl: (userData.photoUrl as string) || null,
    isOnline: (userData.isOnline as boolean) || false,
    lastSeen: userData.lastSeen || null,
    createdAt: userData.createdAt || null,
    updatedAt: userData.updatedAt || null,
  };
}
