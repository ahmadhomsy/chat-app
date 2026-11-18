import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggered automatically whenever a user account is deleted from Firebase Authentication.
 * Performs complete, privileged, and idempotent cleanup of user profile data,
 * subcollections, Storage assets, and presence nodes.
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
    await Promise.all(deleteTokenPromises);

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

    functions.logger.info(`Successfully completed server-side cleanup for user: ${uid}`);
  } catch (error) {
    functions.logger.error(`Error during account cleanup for user ${uid}:`, error);
    // Allow error to throw for Cloud Functions retry mechanism
    throw error;
  }
});
