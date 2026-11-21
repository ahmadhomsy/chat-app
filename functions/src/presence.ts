import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { evaluatePresenceCommit } from './presence_helpers';

/**
 * Server-authoritative presence mirror from Realtime Database to Cloud Firestore.
 *
 * Concurrency & Ordering Architecture (Phase 4.2):
 * - Realtime Database is the sole source of truth for active client connections.
 * - Each client device registers under `/status/{userId}/connections/{deviceId}` with onDisconnect().remove().
 * - When connections change, this function inspects the live connection node.
 * - Out-of-order race conditions are guarded by an ATOMIC Firestore transaction reading
 *   `presenceLastEventTimeMs` from `/users/{userId}` and `/public_users/{userId}`.
 * - Only strictly newer events (`eventTimeMs > committedLastEventTimeMs`) commit.
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
    const eventTimeMs = context.timestamp ? new Date(context.timestamp).getTime() : nowMs;

    // Drop events older than 5 minutes to avoid obsolete updates
    if (nowMs - eventTimeMs > 5 * 60 * 1000) {
      functions.logger.warn(`Dropping stale presence event for user ${userId} (${nowMs - eventTimeMs}ms old).`);
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

      const userLastTime = (userDoc.data()?.presenceLastEventTimeMs as number) || 0;
      const publicLastTime = (publicUserDoc.data()?.presenceLastEventTimeMs as number) || 0;
      const currentCommittedTime = Math.max(userLastTime, publicLastTime);

      const decision = evaluatePresenceCommit(currentCommittedTime, eventTimeMs);
      if (!decision.canCommit) {
        functions.logger.info(
          `Presence: Stale event for ${userId} ignored inside transaction (${eventTimeMs} <= ${currentCommittedTime}, reason: ${decision.reason}).`
        );
        return;
      }

      // Prepare updates
      const updateData: Record<string, any> = {
        isOnline,
        presenceLastEventTimeMs: eventTimeMs,
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
      `Presence: Authoritative update completed for user ${userId}: isOnline=${isOnline}, eventTimeMs=${eventTimeMs}`
    );
  });
