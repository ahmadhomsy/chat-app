import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Rate-limited server-side user lookup endpoint.
 *
 * Privacy Guarantees:
 * - Direct client-side queries against private user documents are forbidden to prevent
 *   unrestricted email scraping and user enumeration.
 * - Requires Firebase Authentication.
 * - Enforces per-user rate limiting (max 15 lookups per minute).
 * - Exact match only (no prefix, wildcard, or regex enumeration).
 * - Returns only public profile fields; sensitive account metadata is never exposed.
 */

interface RateLimitEntry {
  count: number;
  resetAtMs: number;
}

const rateLimitMap = new Map<string, RateLimitEntry>();
const MAX_SEARCH_REQUESTS_PER_MINUTE = 15;
const RATE_LIMIT_WINDOW_MS = 60 * 1000;

export const searchUserByEmail = functions.https.onCall(async (data, context) => {
  // 1. Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const callerUid = context.auth.uid;
  const now = Date.now();

  // 2. Per-user rate limiting
  const callerLimit = rateLimitMap.get(callerUid);
  if (!callerLimit || now > callerLimit.resetAtMs) {
    rateLimitMap.set(callerUid, {
      count: 1,
      resetAtMs: now + RATE_LIMIT_WINDOW_MS,
    });
  } else {
    callerLimit.count++;
    if (callerLimit.count > MAX_SEARCH_REQUESTS_PER_MINUTE) {
      functions.logger.warn(`User ${callerUid} exceeded search rate limit.`);
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Search rate limit exceeded. Please wait a moment before searching again.'
      );
    }
  }

  // 3. Input validation
  const email = typeof data?.email === 'string' ? data.email.trim().toLowerCase() : '';
  if (!email || !email.includes('@') || email.length > 254) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A valid email address must be provided.'
    );
  }

  // 4. Exact-match query using Admin SDK
  try {
    const firestore = admin.firestore();
    const snapshot = await firestore
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return null;
    }

    const doc = snapshot.docs[0];
    if (doc.id === callerUid) {
      // Exclude caller themselves from search results
      return null;
    }

    const userData = doc.data();

    // 5. Expose strictly safe public projection
    return {
      id: doc.id,
      name: (userData.name as string) || 'User',
      email: (userData.email as string) || email,
      photoUrl: (userData.photoUrl as string) || null,
      isOnline: (userData.isOnline as boolean) || false,
      lastSeen: userData.lastSeen ? userData.lastSeen.toDate().toISOString() : null,
    };
  } catch (error: any) {
    functions.logger.error(`Error during searchUserByEmail for ${email}:`, error);
    throw new functions.https.HttpsError('internal', 'Internal search service error.');
  }
});
