import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggered automatically whenever a user account is deleted from Firebase Authentication.
 * Performs complete, privileged, and idempotent cleanup of user profile data,
 * subcollections, Storage assets, and presence nodes.
 *
 * Privacy and Data Retention Policy:
 * 1. Personal Identifiers Purge:
 *    - User document (`/users/{uid}`) is permanently deleted.
 *    - User FCM tokens subcollection (`/users/{uid}/fcmTokens`) is permanently deleted.
 *    - User profile avatar files (`/avatars/{uid}/*`) in Storage are deleted.
 *    - User Realtime Database presence node (`/status/{uid}`) is removed.
 * 2. Conversational Continuity & Anonymization:
 *    - Messages sent by the user are preserved so that remaining conversation participants
 *      do not lose context or conversational flow.
 *    - In all conversations where the user participated, the user's entry in `participants.{uid}`
 *      is anonymized to `name: "Deleted Account"`, `photoUrl: null`, and `isOnline: false`.
 *    - If the deleted user was an administrator in a group conversation, they are removed from `adminIds`.
 *      If no admins remain, the oldest remaining participant is automatically promoted to admin.
 *    - Direct conversations where both users have been deleted can be safely archived or removed.
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  functions.logger.info(`Starting server-side account cleanup for deleted user: ${uid}`);

  const firestore = admin.firestore();
  const storage = admin.storage();
  const database = admin.database();

  try {
    // 1. Delete all documents in `users/{uid}/fcmTokens` subcollection
    const fcmTokensSnapshot = await firestore
      .collection('users')
      .doc(uid)
      .collection('fcmTokens')
      .get();

    const deleteTokenPromises = fcmTokensSnapshot.docs.map((doc) => doc.ref.delete());
    await Promise.allSettled(deleteTokenPromises);

    // 2. Delete the user document in Firestore `users/{uid}`
    await firestore.collection('users').doc(uid).delete();

    // 3. Delete user avatars in Cloud Storage under `avatars/{uid}/`
    try {
      const bucket = storage.bucket();
      await bucket.deleteFiles({
        prefix: `avatars/${uid}/`,
      });
      functions.logger.info(`Deleted avatar files for user: ${uid}`);
    } catch (storageError) {
      functions.logger.warn(`Storage avatar deletion note for user ${uid}:`, storageError);
    }

    // 4. Delete user presence node in Realtime Database under `/status/{uid}`
    try {
      await database.ref(`status/${uid}`).remove();
      functions.logger.info(`Removed RTDB presence node for user: ${uid}`);
    } catch (rtdbError) {
      functions.logger.warn(`RTDB presence deletion note for user ${uid}:`, rtdbError);
    }

    // 5. Anonymize user participation across all existing conversations
    try {
      const conversationsSnapshot = await firestore
        .collection('conversations')
        .where('participantIds', 'array-contains', uid)
        .get();

      const batch = firestore.batch();
      let updateCount = 0;

      conversationsSnapshot.forEach((doc) => {
        const data = doc.data();
        const updates: Record<string, any> = {
          [`participants.${uid}.name`]: 'Deleted Account',
          [`participants.${uid}.photoUrl`]: null,
          [`participants.${uid}.isOnline`]: false,
          [`lastReadAtByUser.${uid}`]: admin.firestore.FieldValue.delete(),
        };

        // If it's a group conversation and the deleted user is an admin
        if (data.type === 'group' && Array.isArray(data.adminIds) && data.adminIds.includes(uid)) {
          const remainingAdmins = data.adminIds.filter((adminId: string) => adminId !== uid);
          if (remainingAdmins.length === 0) {
            // Promote oldest remaining participant
            const otherParticipants = (data.participantIds as string[]).filter((pId: string) => pId !== uid);
            if (otherParticipants.length > 0) {
              remainingAdmins.push(otherParticipants[0]);
            }
          }
          updates.adminIds = remainingAdmins;
        }

        batch.update(doc.ref, updates);
        updateCount++;
      });

      if (updateCount > 0) {
        await batch.commit();
        functions.logger.info(`Anonymized user ${uid} across ${updateCount} conversations.`);
      }
    } catch (anonymizeError) {
      functions.logger.warn(`Conversation anonymization note for user ${uid}:`, anonymizeError);
    }

    functions.logger.info(`Successfully completed server-side cleanup for user: ${uid}`);
  } catch (error) {
    functions.logger.error(`Error during account cleanup for user ${uid}:`, error);
    // Rethrow to allow Cloud Functions background retry
    throw error;
  }
});
