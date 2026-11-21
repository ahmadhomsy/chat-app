import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { shouldProcessPresenceEvent } from './presence_helpers';

/**
 * Server-authoritative presence mirror from Realtime Database to Cloud Firestore.
 *
 * Concurrency & Ordering Architecture:
 * - Realtime Database is the sole source of truth for active client connections.
 * - Each client device registers under `/status/{userId}/connections/{deviceId}` with onDisconnect().remove().
 * - When connections change, this function inspects the live connection node.
 * - Out-of-order race conditions are guarded by comparing the trigger's `context.timestamp`
 *   against `presenceLastEventTimeMs` stored in Firestore. If a newer transition has already
 *   been committed, stale executions abort cleanly.
 * - If 1+ connections exist -> mirrors `isOnline: true` to `/users/{userId}` and `/public_users/{userId}`.
 * - If 0 connections exist -> mirrors `isOnline: false` and the authoritative RTDB `lastSeen` timestamp.
 * - Clients never directly write `isOnline` or `lastSeen` to Firestore (forbidden by Security Rules).
 */
export const onUserStatusChanged = functions.database
  .ref('/status/{userId}/connections')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    const eventTimeMs = context.timestamp ? new Date(context.timestamp).getTime() : Date.now();
    const firestore = admin.firestore();
    const rtdb = admin.database();

    try {
      const userDocRef = firestore.collection('users').doc(userId);
      const publicUserDocRef = firestore.collection('public_users').doc(userId);

      const [userDoc, publicUserDoc] = await Promise.all([
        userDocRef.get(),
        publicUserDocRef.get(),
      ]);

      if (!userDoc.exists && !publicUserDoc.exists) {
        // User may have been deleted; no-op
        return;
      }

      // Check version / ordering guard to prevent stale updates from overwriting newer transitions
      const userLastTime = (userDoc.data()?.presenceLastEventTimeMs as number) || 0;
      const publicLastTime = (publicUserDoc.data()?.presenceLastEventTimeMs as number) || 0;
      const currentCommittedTime = Math.max(userLastTime, publicLastTime);

      if (!shouldProcessPresenceEvent(currentCommittedTime, eventTimeMs)) {
        functions.logger.info(
          `Stale presence event for user ${userId} discarded (${eventTimeMs} < ${currentCommittedTime}).`
        );
        return;
      }

      // Fetch fresh live state from RTDB
      const liveConnectionsSnapshot = await rtdb.ref(`status/${userId}/connections`).once('value');
      const isOnline = liveConnectionsSnapshot.exists() && liveConnectionsSnapshot.numChildren() > 0;

      const batch = firestore.batch();

      if (isOnline) {
        const onlineUpdate = {
          isOnline: true,
          presenceLastEventTimeMs: eventTimeMs,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (userDoc.exists) {
          batch.update(userDocRef, onlineUpdate);
        }
        if (publicUserDoc.exists) {
          batch.update(publicUserDocRef, onlineUpdate);
        }

        await batch.commit();
        functions.logger.info(`Presence: User ${userId} is now ONLINE (${liveConnectionsSnapshot.numChildren()} active device(s)).`);
      } else {
        // Fetch authoritative lastSeen timestamp from RTDB
        const lastSeenSnapshot = await rtdb.ref(`status/${userId}/lastSeen`).once('value');
        const lastSeenVal = lastSeenSnapshot.val();

        const lastSeenDate = typeof lastSeenVal === 'number'
          ? admin.firestore.Timestamp.fromMillis(lastSeenVal)
          : admin.firestore.FieldValue.serverTimestamp();

        const offlineUpdate = {
          isOnline: false,
          lastSeen: lastSeenDate,
          presenceLastEventTimeMs: eventTimeMs,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (userDoc.exists) {
          batch.update(userDocRef, offlineUpdate);
        }
        if (publicUserDoc.exists) {
          batch.update(publicUserDocRef, offlineUpdate);
        }

        await batch.commit();
        functions.logger.info(`Presence: User ${userId} is now OFFLINE (all devices disconnected).`);
      }
    } catch (error) {
      functions.logger.error(`Error synchronizing presence for user ${userId}:`, error);
      throw error;
    }
  });
