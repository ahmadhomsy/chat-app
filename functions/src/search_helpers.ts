import * as admin from 'firebase-admin';

export const MAX_SEARCH_REQUESTS_PER_MINUTE = 15;
export const RATE_LIMIT_WINDOW_MS = 60 * 1000;

export interface RateLimitRecord {
  count: number;
  windowStartMs: number;
  expiresAt: admin.firestore.Timestamp;
}

/**
 * Checks and updates the atomic, shared per-user search rate limit stored in Firestore `_rate_limits`.
 * Throws an error with code 'resource-exhausted' if the limit is exceeded within the rolling window.
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

    if (!doc.exists) {
      transaction.set(rateLimitRef, {
        count: 1,
        windowStartMs: nowMs,
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMs + windowMs * 2),
      });
      return;
    }

    const data = doc.data() as RateLimitRecord;
    const windowStart = data.windowStartMs || 0;

    if (nowMs - windowStart > windowMs) {
      // Window expired, reset counter and window start
      transaction.update(rateLimitRef, {
        count: 1,
        windowStartMs: nowMs,
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMs + windowMs * 2),
      });
    } else {
      if (data.count >= maxRequests) {
        const error = new Error('Search rate limit exceeded. Please wait a moment before searching again.');
        (error as any).code = 'resource-exhausted';
        throw error;
      }

      transaction.update(rateLimitRef, {
        count: admin.firestore.FieldValue.increment(1),
      });
    }
  });
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
    lastSeen: userData.lastSeen ? userData.lastSeen.toDate().toISOString() : null,
  };
}
