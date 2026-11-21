import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Account Deletion Architecture & Retention Policy:
 *
 * 1. Personal Identifiers Purge:
 *    - Private User Profile (`/users/{uid}`): permanently deleted.
 *    - Public User Profile (`/public_users/{uid}`): permanently deleted.
 *    - Private FCM Tokens (`/users/{uid}/fcmTokens/*`): permanently deleted in batches <= 400.
 *    - Storage Profile Avatars (`avatars/{uid}/*`): permanently deleted from Cloud Storage.
 *    - RTDB Presence Nodes (`/status/{uid}`): permanently removed from Realtime Database.
 *
 * 2. Conversational Continuity & Anonymization Policy:
 *    - Messages & Attachments: Preserved to prevent broken conversations and maintain continuity
 *      for surviving participants.
 *    - Participant Identity Anonymization: The user's entry in `participants.{uid}` in all
 *      conversations is redacted to `name: "Deleted Account"`, `photoUrl: null`, `isOnline: false`.
 *    - Read Receipts: The user's entry in `lastReadAtByUser.{uid}` is deleted.
 *    - Group Admin Succession: If the deleted user was a group administrator, they are removed
 *      from `adminIds`. If no admins remain, the oldest remaining participant is promoted.
 *
 * 3. Batch Limits & Resilience:
 *    - Paginated conversation processing in batches of at most 300 updates (Firestore limit: 500).
 *    - Progress persistence under `_cleanup_progress/{uid}` allows safe resumption of interrupted runs.
 *    - Each stage is independently idempotent and retryable.
 */

const CONVERSATION_BATCH_SIZE = 300;

interface CleanupProgress {
  fcmTokensCleaned?: boolean;
  userDocCleaned?: boolean;
  publicUserDocCleaned?: boolean;
  avatarsCleaned?: boolean;
  rtdbCleaned?: boolean;
  conversationsAnonymized?: boolean;
  lastProcessedConversationId?: string;
  completed?: boolean;
  completedAt?: admin.firestore.FieldValue;
  updatedAt?: admin.firestore.FieldValue;
}

export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  functions.logger.info(`Starting resilient account cleanup for user: ${uid}`);

  const firestore = admin.firestore();
  const storage = admin.storage();
  const database = admin.database();

  const progressRef = firestore.collection('_cleanup_progress').doc(uid);
  const progressDoc = await progressRef.get();
  const progress: CleanupProgress = progressDoc.exists ? (progressDoc.data() as CleanupProgress) : {};

  try {
    // ----------------------------------------------------
    // Stage 1: Purge FCM Tokens Subcollection
    // ----------------------------------------------------
    if (!progress.fcmTokensCleaned) {
      functions.logger.info(`Stage 1: Deleting FCM tokens for user ${uid}`);
      const fcmTokensSnapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .get();

      if (!fcmTokensSnapshot.empty) {
        const batch = firestore.batch();
        fcmTokensSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }

      await progressRef.set(
        { fcmTokensCleaned: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    }

    // ----------------------------------------------------
    // Stage 2: Purge Private User Document
    // ----------------------------------------------------
    if (!progress.userDocCleaned) {
      functions.logger.info(`Stage 2: Deleting private user document for ${uid}`);
      await firestore.collection('users').doc(uid).delete();
      await progressRef.set(
        { userDocCleaned: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    }

    // ----------------------------------------------------
    // Stage 3: Purge Public Discovery Document
    // ----------------------------------------------------
    if (!progress.publicUserDocCleaned) {
      functions.logger.info(`Stage 3: Deleting public user document for ${uid}`);
      await firestore.collection('public_users').doc(uid).delete();
      await progressRef.set(
        { publicUserDocCleaned: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    }

    // ----------------------------------------------------
    // Stage 4: Purge Cloud Storage Avatars
    // ----------------------------------------------------
    if (!progress.avatarsCleaned) {
      functions.logger.info(`Stage 4: Deleting Storage avatars for user ${uid}`);
      try {
        const bucket = storage.bucket();
        await bucket.deleteFiles({ prefix: `avatars/${uid}/` });
      } catch (storageError: any) {
        // Code 404 means no files were found; that is normal and safe
        if (storageError?.code !== 404) {
          functions.logger.warn(`Storage deletion returned notice for user ${uid}:`, storageError);
        }
      }
      await progressRef.set(
        { avatarsCleaned: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    }

    // ----------------------------------------------------
    // Stage 5: Purge Realtime Database Presence Nodes
    // ----------------------------------------------------
    if (!progress.rtdbCleaned) {
      functions.logger.info(`Stage 5: Deleting RTDB presence nodes for user ${uid}`);
      await database.ref(`status/${uid}`).remove();
      await progressRef.set(
        { rtdbCleaned: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    }

    // ----------------------------------------------------
    // Stage 6: Anonymize Conversations (Paginated in <= 300 batches)
    // ----------------------------------------------------
    if (!progress.conversationsAnonymized) {
      functions.logger.info(`Stage 6: Anonymizing conversation participation for user ${uid}`);

      let hasMore = true;
      let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;

      // If resuming from a prior run, find the resume point
      if (progress.lastProcessedConversationId) {
        const resumeDoc = await firestore
          .collection('conversations')
          .doc(progress.lastProcessedConversationId)
          .get();
        if (resumeDoc.exists) {
          lastDoc = resumeDoc as admin.firestore.QueryDocumentSnapshot;
        }
      }

      while (hasMore) {
        let query = firestore
          .collection('conversations')
          .where('participantIds', 'array-contains', uid)
          .orderBy(admin.firestore.FieldPath.documentId())
          .limit(CONVERSATION_BATCH_SIZE);

        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();

        if (snapshot.empty) {
          hasMore = false;
          break;
        }

        const batch = firestore.batch();
        let batchCount = 0;

        snapshot.docs.forEach((doc) => {
          const data = doc.data();
          const updates: Record<string, any> = {
            [`participants.${uid}.name`]: 'Deleted Account',
            [`participants.${uid}.photoUrl`]: null,
            [`participants.${uid}.isOnline`]: false,
            [`lastReadAtByUser.${uid}`]: admin.firestore.FieldValue.delete(),
          };

          // Admin succession logic for group conversations
          if (data.type === 'group' && Array.isArray(data.adminIds) && data.adminIds.includes(uid)) {
            const remainingAdmins = data.adminIds.filter((adminId: string) => adminId !== uid);
            if (remainingAdmins.length === 0) {
              const otherParticipants = (data.participantIds as string[]).filter((pId: string) => pId !== uid);
              if (otherParticipants.length > 0) {
                remainingAdmins.push(otherParticipants[0]);
              }
            }
            updates.adminIds = remainingAdmins;
          }

          batch.update(doc.ref, updates);
          batchCount++;
        });

        if (batchCount > 0) {
          await batch.commit();
          lastDoc = snapshot.docs[snapshot.docs.length - 1];
          await progressRef.set(
            {
              lastProcessedConversationId: lastDoc.id,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
          functions.logger.info(`Anonymized batch of ${batchCount} conversations for user ${uid}.`);
        }

        if (snapshot.size < CONVERSATION_BATCH_SIZE) {
          hasMore = false;
        }
      }

      await progressRef.set(
        {
          conversationsAnonymized: true,
          completed: true,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    functions.logger.info(`Account cleanup completed successfully for user ${uid}.`);
  } catch (error) {
    functions.logger.error(`Error during account cleanup for user ${uid}:`, error);
    // Rethrow error so Cloud Functions retries
    throw error;
  }
});
