import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function that synchronizes Realtime Database presence changes to Cloud Firestore.
 * Triggered whenever a device connection node is added or removed under `/status/{userId}/connections`.
 */
export const onUserStatusChanged = functions.database
  .ref('/status/{userId}/connections')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    const firestore = admin.firestore();

    try {
      const connectionsSnapshot = change.after;
      const isOnline = connectionsSnapshot.exists() && connectionsSnapshot.numChildren() > 0;

      const userDocRef = firestore.collection('users').doc(userId);
      const userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        // User may have been deleted
        return;
      }

      if (isOnline) {
        await userDocRef.update({
          isOnline: true,
        });
        functions.logger.info(`Presence: User ${userId} is now ONLINE (${connectionsSnapshot.numChildren()} active devices).`);
      } else {
        // Fetch lastSeen timestamp from RTDB if available
        const lastSeenSnapshot = await admin.database().ref(`status/${userId}/lastSeen`).once('value');
        const lastSeenVal = lastSeenSnapshot.val();

        const lastSeenDate = typeof lastSeenVal === 'number'
          ? admin.firestore.Timestamp.fromMillis(lastSeenVal)
          : admin.firestore.FieldValue.serverTimestamp();

        await userDocRef.update({
          isOnline: false,
          lastSeen: lastSeenDate,
        });
        functions.logger.info(`Presence: User ${userId} is now OFFLINE (all devices disconnected).`);
      }
    } catch (error) {
      functions.logger.error(`Error synchronizing presence for user ${userId}:`, error);
    }
  });
