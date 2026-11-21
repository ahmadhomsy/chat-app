export const FCM_MULTICAST_CHUNK_SIZE = 500;
export const LOCK_LEASE_MS = 120000; // 120 seconds (2 minutes) lease timeout
export const MAX_EVENT_AGE_MS = 10 * 60 * 1000; // 10 minutes max retry window

export interface TokenEntry {
  token: string;
  userId: string;
  docRef: any;
}

export type FcmErrorCategory = 'permanent' | 'transient';

/**
 * Classifies FCM error codes into permanent (invalid/unregistered tokens requiring pruning)
 * versus transient (retryable network, server, or rate-limit issues).
 */
export function classifyFcmError(errorCode: string): FcmErrorCategory {
  if (
    errorCode === 'messaging/invalid-registration-token' ||
    errorCode === 'messaging/registration-token-not-registered'
  ) {
    return 'permanent';
  }
  return 'transient';
}

/**
 * Evaluates whether an event invocation has exceeded the maximum permissible age for retries.
 * In Cloud Functions 1st gen event triggers, events older than MAX_EVENT_AGE_MS are dropped
 * to prevent indefinite retry loops on permanent unrecoverable conditions.
 */
export function isEventExpiredForRetry(
  eventTimestampMs: number,
  nowMs: number = Date.now(),
  maxAgeMs: number = MAX_EVENT_AGE_MS
): boolean {
  return nowMs - eventTimestampMs > maxAgeMs;
}

/**
 * Classifies errors into retryable (transient network, FCM server, or timeouts)
 * versus non-retryable (invalid schema, malformed payload, missing conversation).
 */
export function isRetryableNotificationError(error: any): boolean {
  if (!error) return false;
  const msg = (error.message || String(error)).toLowerCase();
  const code = (error.code || '').toLowerCase();

  // Terminal / non-retryable conditions
  if (
    code === 'invalid-argument' ||
    code === 'not-found' ||
    msg.includes('no message data') ||
    msg.includes('parent conversation not found')
  ) {
    return false;
  }

  // Transient / network / server errors are retryable
  return true;
}

/**
 * Filters token list, excluding tokens already successfully delivered or confirmed permanently invalid.
 */
export function filterTokensForDispatch(
  allTokens: TokenEntry[],
  previouslySentTokens: string[] = [],
  permanentlyFailedTokens: string[] = []
): TokenEntry[] {
  const sentSet = new Set(previouslySentTokens);
  const failedSet = new Set(permanentlyFailedTokens);
  return allTokens.filter((entry) => !sentSet.has(entry.token) && !failedSet.has(entry.token));
}

/**
 * Partitions items into chunks of at most chunkSize (<= 500 for FCM multicast).
 */
export function chunkItems<T>(items: T[], chunkSize: number = FCM_MULTICAST_CHUNK_SIZE): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    chunks.push(items.slice(i, i + chunkSize));
  }
  return chunks;
}

export interface ChunkProcessResult {
  newlySentTokens: string[];
  newlyPermanentlyFailedTokens: string[];
  invalidDocRefsToDelete: any[];
  transientFailures: { token: string; code: string; message: string }[];
}

/**
 * Evaluates individual responses from an FCM multicast call.
 */
export function processMulticastResponses(
  chunk: TokenEntry[],
  responses: Array<{ success: boolean; error?: { code: string; message: string } }>
): ChunkProcessResult {
  const newlySentTokens: string[] = [];
  const newlyPermanentlyFailedTokens: string[] = [];
  const invalidDocRefsToDelete: any[] = [];
  const transientFailures: { token: string; code: string; message: string }[] = [];

  responses.forEach((resp, idx) => {
    const entry = chunk[idx];
    if (!entry) return;

    if (resp.success) {
      newlySentTokens.push(entry.token);
    } else if (resp.error) {
      const code = resp.error.code || 'unknown';
      const category = classifyFcmError(code);

      if (category === 'permanent') {
        newlyPermanentlyFailedTokens.push(entry.token);
        invalidDocRefsToDelete.push(entry.docRef);
      } else {
        transientFailures.push({
          token: entry.token,
          code,
          message: resp.error.message || '',
        });
      }
    }
  });

  return {
    newlySentTokens,
    newlyPermanentlyFailedTokens,
    invalidDocRefsToDelete,
    transientFailures,
  };
}

export interface LockEvaluation {
  canProcess: boolean;
  reason?: 'already_sent' | 'in_progress' | 'acquired' | 'recovered';
  previouslySentTokens: string[];
  permanentlyFailedTokens: string[];
}

/**
 * Evaluates concurrency lock and recovery state for an event.
 */
export function evaluateEventLock(
  eventData: any | undefined,
  nowMs: number,
  leaseMs: number = LOCK_LEASE_MS
): LockEvaluation {
  if (!eventData) {
    return {
      canProcess: true,
      reason: 'acquired',
      previouslySentTokens: [],
      permanentlyFailedTokens: [],
    };
  }

  if (eventData.state === 'sent') {
    return {
      canProcess: false,
      reason: 'already_sent',
      previouslySentTokens: eventData.sentTokens || [],
      permanentlyFailedTokens: eventData.failedTokens || [],
    };
  }

  const lockedAtMs = eventData.lockedAt?.toMillis ? eventData.lockedAt.toMillis() : (eventData.lockedAtMs || 0);
  const leaseActive = eventData.state === 'processing' && (nowMs - lockedAtMs) < leaseMs;

  if (leaseActive) {
    return {
      canProcess: false,
      reason: 'in_progress',
      previouslySentTokens: eventData.sentTokens || [],
      permanentlyFailedTokens: eventData.failedTokens || [],
    };
  }

  return {
    canProcess: true,
    reason: 'recovered',
    previouslySentTokens: eventData.sentTokens || [],
    permanentlyFailedTokens: eventData.failedTokens || [],
  };
}
