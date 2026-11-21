import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { evaluatePresenceCommit, parseEventTimestamp } from './presence_helpers';

/**
 * Server-authoritative presence mirror from Realtime Database to Cloud Firestore.
 *
 * Concurrency & Ordering Architecture (Phase 4.2 & Phase 4.3):
 * - Realtime Database is the sole source of truth for active client connections.
 * - Each client device registers under `/status/{userId}/connections/{deviceId}` with onDisconnect().remove().
 * - When connections change, this function inspects the live connection node.
 * - Out-of-order race conditions are guarded by an ATOMIC Firestore transaction reading
 *   committed timestamps from `/users/{userId}` and `/public_users/{userId}`.
 * - High-precision timestamp ordering: preserves microsecond precision from context.timestamp RFC 3339 string.
 * - Only strictly newer events (`incomingMicros > committedMicros`) commit.
 *   Older and equal timestamps abort inside the transaction, guaranteeing that concurrent
 *   or out-of-order executions cannot overwrite fresher presence state.
 * - If 1+ connections exist -> mirrors `isOnline: true` to `/users/{userId}` and `/public_users/{userId}`.
 * - If 0 connections exist -> mirrors `isOnline: false` and the authoritative RTDB `lastSeen` timestamp.
 * - Clients never directly write `isOnline` or `lastSeen` to Firestore (forbidden by Security Rules).
 */
export const onUserStatusChanged = functions
  .runWith({ failurePolicy: true, timeoutSeconds: 60, memory: '256MB' })
  .database.ref('/status/{userId}/connections')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    const nowMs = Date.now();
    const incomingTimestamp = parseEventTimestamp(context.timestamp);

    // Drop events older than 5 minutes to avoid obsolete updates
    if (nowMs - incomingTimestamp.millis > 5 * 60 * 1000) {
      functions.logger.warn(`Dropping stale presence event for user ${userId} (${nowMs - incomingTimestamp.millis}ms old).`);
      return;
    }

    const firestore = admin.firestore();
    const rtdb = admin.database();

    // 1. Fetch fresh authoritative state from RTDB (RTDB is sole source of truth)
    const liveConnectionsSnapshot = await rtdb.ref(`status/${userId}/connections`).once('value');
    const isOnline = liveConnectionsSnapshot.exists() && liveConnectionsSnapshot.numChildren() > 0;

    let lastSeenTimestamp: admin.firestore.Timestamp | admin.firestore.FieldValue = admin.firestore.FieldValue.serverTimestamp();
    if (!isOnline) {
      const lastSeenSnapshot = await rtdb.ref(`status/${userId}/lastSeen`).once('value');
      const lastSeenVal = lastSeenSnapshot.val();
      if (typeof lastSeenVal === 'number') {
        lastSeenTimestamp = admin.firestore.Timestamp.fromMillis(lastSeenVal);
      }
    }

    const userDocRef = firestore.collection('users').doc(userId);
    const publicUserDocRef = firestore.collection('public_users').doc(userId);

    // 2. Atomic Firestore Transaction: read committed presence timestamp and write atomically
    await firestore.runTransaction(async (transaction) => {
      const [userDoc, publicUserDoc] = await Promise.all([
        transaction.get(userDocRef),
        transaction.get(publicUserDocRef),
      ]);

      if (!userDoc.exists && !publicUserDoc.exists) {
        // User does not exist or has been deleted
        return;
      }

      const userDocData = userDoc.data();
      const publicUserDocData = publicUserDoc.data();

      const userMicros = (userDocData?.presenceLastEventTimeMicros as number) || ((userDocData?.presenceLastEventTimeMs as number) || 0) * 1000;
      const publicMicros = (publicUserDocData?.presenceLastEventTimeMicros as number) || ((publicUserDocData?.presenceLastEventTimeMs as number) || 0) * 1000;
      const currentCommittedMicros = Math.max(userMicros, publicMicros);

      const decision = evaluatePresenceCommit(currentCommittedMicros, incomingTimestamp);
      if (!decision.canCommit) {
        functions.logger.info(
          `Presence: Stale event for ${userId} ignored inside transaction (${incomingTimestamp.micros} <= ${currentCommittedMicros}, reason: ${decision.reason}).`
        );
        return;
      }

      // Prepare updates
      const updateData: Record<string, any> = {
        isOnline,
        presenceLastEventTimeMs: incomingTimestamp.millis,
        presenceLastEventTimeMicros: Number(incomingTimestamp.micros),
        presenceLastEventTimeIso: incomingTimestamp.isoString,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (!isOnline) {
        updateData.lastSeen = lastSeenTimestamp;
      }

      if (userDoc.exists) {
        transaction.update(userDocRef, updateData);
      }
      if (publicUserDoc.exists) {
        transaction.update(publicUserDocRef, updateData);
      }
    });

    functions.logger.info(
      `Presence: Authoritative update completed for user ${userId}: isOnline=${isOnline}, micros=${incomingTimestamp.micros}`
    );
  });
