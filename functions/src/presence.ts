import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Server-authoritative presence mirror from Realtime Database to Cloud Firestore.
 * 
 * Multi-device architecture:
 * - Realtime Database is the sole source of truth for active client connections.
 * - Each client device registers under `/status/{userId}/connections/{deviceId}` with onDisconnect().remove().
 * - When connections change, this function inspects the live connection node.
 * - If 1+ connections exist -> mirrors `isOnline: true` to `/users/{userId}` and `/public_users/{userId}`.
 * - If 0 connections exist -> mirrors `isOnline: false` and the authoritative RTDB `lastSeen` timestamp.
 * - Clients never directly write `isOnline` or `lastSeen` to Firestore (forbidden by Security Rules).
 */
export const onUserStatusChanged = functions.database
  .ref('/status/{userId}/connections')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    const firestore = admin.firestore();
    const rtdb = admin.database();

    try {
      // Fetch fresh live state from RTDB to prevent stale updates or out-of-order race conditions
      const liveConnectionsSnapshot = await rtdb.ref(`status/${userId}/connections`).once('value');
      const isOnline = liveConnectionsSnapshot.exists() && liveConnectionsSnapshot.numChildren() > 0;

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

      const batch = firestore.batch();

      if (isOnline) {
        const onlineUpdate = {
          isOnline: true,
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
      throw error; // Allow Cloud Functions retry on transient failure
    }
  });
