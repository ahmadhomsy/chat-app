import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { enforceSearchRateLimit, sanitizeSearchProfile } from './search_helpers';

/**
 * Rate-limited server-side user lookup endpoint.
 *
 * Privacy Guarantees:
 * - Direct client-side queries against private user documents are forbidden to prevent
 *   unrestricted email scraping and user enumeration.
 * - Requires Firebase Authentication.
 * - Enforces atomic, shared per-user rate limiting stored in `_rate_limits/{uid}` (max 15/min).
 * - Exact match only (no prefix, wildcard, or regex enumeration).
 * - Returns only public profile fields; email and sensitive account metadata are never exposed.
 */
export const searchUserByEmail = functions.https.onCall(async (data, context) => {
  // 1. Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const callerUid = context.auth.uid;
  const firestore = admin.firestore();

  // 2. Atomic, shared per-user rate limiting via Firestore
  try {
    await enforceSearchRateLimit(firestore, callerUid);
  } catch (err: any) {
    if (err?.code === 'resource-exhausted') {
      functions.logger.warn(`User ${callerUid} exceeded search rate limit.`);
      throw new functions.https.HttpsError('resource-exhausted', err.message);
    }
    functions.logger.error(`Rate limiter storage error for user ${callerUid}:`, err);
    throw new functions.https.HttpsError('internal', 'Internal rate limiting error.');
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

    // 5. Expose strictly safe public projection (email excluded)
    return sanitizeSearchProfile(doc.id, doc.data());
  } catch (error: any) {
    functions.logger.error(`Error during searchUserByEmail for ${email}:`, error);
    throw new functions.https.HttpsError('internal', 'Internal search service error.');
  }
});
