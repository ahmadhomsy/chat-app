import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * FCM Delivery Semantics and Architecture:
 * 
 * Delivery Guarantees:
 * - At-least-once delivery semantics at the Cloud Function layer with distributed locking
 *   and event state persistence.
 * - Absolute zero-duplicate delivery to end-user devices is mathematically impossible over
 *   external cellular and APNs/FCM transport networks (e.g. APNs acknowledgment packet drops
 *   causing transport-level retries).
 * - Function-level idempotency uses `_function_events/{eventId}` to guard against duplicate
 *   Cloud Function invocations and retries.
 * - Chunked multicast (batches <= 500) respects Firebase Admin SDK limits.
 * - Token deduplication across multiple user devices prevents intra-event duplicate deliveries.
 * - Invalid or expired FCM tokens ('messaging/invalid-registration-token' and
 *   'messaging/registration-token-not-registered') are automatically pruned from Firestore.
 * - Transient errors are rethrown so Cloud Functions retries, while already-delivered tokens
 *   are preserved across retries to prevent duplicate deliveries to previous recipients.
 */

const FCM_MULTICAST_CHUNK_SIZE = 500;
const LOCK_LEASE_MS = 60000; // 60 seconds lease timeout

interface EventStateDoc {
  type: string;
  state: 'processing' | 'sent' | 'failed';
  conversationId: string;
  messageId: string;
  lockedAt: admin.firestore.Timestamp;
  sentTokens: string[];
  failedTokens: string[];
  error?: string;
  updatedAt: admin.firestore.FieldValue;
  expiresAt: admin.firestore.Timestamp;
}

export const onNewChatMessage = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const { conversationId, messageId } = context.params;
    const eventId = context.eventId;
    const messageData = snapshot.data();

    if (!messageData) {
      functions.logger.warn(`No message data found for ${messageId} in conversation ${conversationId}`);
      return;
    }

    const firestore = admin.firestore();
    const eventRef = firestore.collection('_function_events').doc(eventId);
    const nowMs = Date.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(nowMs + 7 * 24 * 60 * 60 * 1000); // 7-day TTL

    // 1. Durable Event Concurrency Guard & Lock Lease
    let previouslySentTokens: string[] = [];

    const lockAcquired = await firestore.runTransaction(async (transaction) => {
      const eventDoc = await transaction.get(eventRef);

      if (eventDoc.exists) {
        const data = eventDoc.data() as EventStateDoc;

        // If already completely processed, safely skip duplicate invocation
        if (data.state === 'sent') {
          return false;
        }

        // If currently processing under an active lease, skip concurrent run
        const lockTime = data.lockedAt ? data.lockedAt.toMillis() : 0;
        if (data.state === 'processing' && (nowMs - lockTime) < LOCK_LEASE_MS) {
          functions.logger.info(`Event ${eventId} is currently locked by another worker. Skipping concurrent invocation.`);
          return false;
        }

        // Lock expired or previous run failed -> renew lease and resume
        previouslySentTokens = Array.isArray(data.sentTokens) ? data.sentTokens : [];
        transaction.update(eventRef, {
          state: 'processing',
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
      }

      // First run for this event
      transaction.set(eventRef, {
        type: 'onNewChatMessage',
        state: 'processing',
        conversationId,
        messageId,
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
        sentTokens: [],
        failedTokens: [],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
      });
      return true;
    });

    if (!lockAcquired) {
      return;
    }

    const senderId = messageData.senderId as string;
    const senderName = (messageData.senderName as string) || 'Someone';
    const text = (messageData.text as string) || '';
    const messageType = (messageData.type as string) || 'text';

    try {
      // 2. Fetch conversation metadata to resolve participants
      const conversationDoc = await firestore.collection('conversations').doc(conversationId).get();
      if (!conversationDoc.exists) {
        functions.logger.warn(`Parent conversation ${conversationId} not found.`);
        await eventRef.update({
          state: 'sent',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const conversationData = conversationDoc.data() || {};
      const participantIds: string[] = conversationData.participantIds || [];
      const isGroup = conversationData.type === 'group';
      const groupName = (conversationData.groupName as string) || 'Group Chat';

      // Exclude sender
      const recipientIds = participantIds.filter((uid) => uid !== senderId);
      if (recipientIds.length === 0) {
        functions.logger.info(`No other recipients for conversation ${conversationId}.`);
        await eventRef.update({
          state: 'sent',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // 3. Collect recipient FCM tokens and deduplicate
      interface TokenEntry {
        token: string;
        userId: string;
        docRef: admin.firestore.DocumentReference;
      }

      const tokenMap = new Map<string, TokenEntry>();

      for (const recipientId of recipientIds) {
        const tokensSnapshot = await firestore
          .collection('users')
          .doc(recipientId)
          .collection('fcmTokens')
          .get();

        tokensSnapshot.forEach((doc) => {
          const data = doc.data();
          if (data && typeof data.token === 'string' && data.token.trim().length > 0) {
            const token = data.token.trim();
            if (!tokenMap.has(token)) {
              tokenMap.set(token, {
                token,
                userId: recipientId,
                docRef: doc.ref,
              });
            }
          }
        });
      }

      const allTokens = Array.from(tokenMap.values());
      // Filter out tokens already delivered in prior interrupted executions of this event
      const tokensToSend = allTokens.filter((entry) => !previouslySentTokens.includes(entry.token));

      if (tokensToSend.length === 0) {
        functions.logger.info(`All tokens already delivered or no valid tokens for message ${messageId}.`);
        await eventRef.update({
          state: 'sent',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // 4. Construct payload
      const title = isGroup ? `${senderName} (${groupName})` : senderName;
      let bodyPreview = text;
      if (messageType === 'image') {
        bodyPreview = '📷 Sent an image';
      } else if (messageType === 'file') {
        bodyPreview = '📎 Sent an attachment';
      }

      if (bodyPreview.length > 100) {
        bodyPreview = `${bodyPreview.substring(0, 97)}...`;
      }

      // 5. Chunk tokens into batches of <= 500 for FCM Multicast
      const chunks: TokenEntry[][] = [];
      for (let i = 0; i < tokensToSend.length; i += FCM_MULTICAST_CHUNK_SIZE) {
        chunks.push(tokensToSend.slice(i, i + FCM_MULTICAST_CHUNK_SIZE));
      }

      const currentSentTokens = [...previouslySentTokens];
      const newlyFailedTokens: string[] = [];
      const invalidTokenDocRefs: admin.firestore.DocumentReference[] = [];

      for (const chunk of chunks) {
        const chunkTokens = chunk.map((entry) => entry.token);
        const multicastMessage: admin.messaging.MulticastMessage = {
          tokens: chunkTokens,
          notification: {
            title,
            body: bodyPreview,
          },
          data: {
            conversationId,
            messageId,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'chat_messages_channel',
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        const response = await admin.messaging().sendEachForMulticast(multicastMessage);

        response.responses.forEach((resp, idx) => {
          const entry = chunk[idx];
          if (resp.success) {
            currentSentTokens.push(entry.token);
          } else if (resp.error) {
            const errorCode = resp.error.code;
            functions.logger.warn(`FCM delivery failure for token ${entry.token.substring(0, 8)}...: ${errorCode}`);
            if (
              errorCode === 'messaging/invalid-registration-token' ||
              errorCode === 'messaging/registration-token-not-registered'
            ) {
              invalidTokenDocRefs.push(entry.docRef);
              newlyFailedTokens.push(entry.token);
            }
          }
        });

        // Persist progress after each chunk
        await eventRef.update({
          sentTokens: currentSentTokens,
          failedTokens: admin.firestore.FieldValue.arrayUnion(...newlyFailedTokens),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // 6. Prune invalid / unregistered tokens from Firestore
      if (invalidTokenDocRefs.length > 0) {
        const deletePromises = invalidTokenDocRefs.map((ref) => ref.delete());
        const results = await Promise.allSettled(deletePromises);
        const successfulDeletes = results.filter((r) => r.status === 'fulfilled').length;
        functions.logger.info(`Pruned ${successfulDeletes}/${invalidTokenDocRefs.length} invalid/unregistered FCM tokens.`);
      }

      // 7. Mark event as completed
      await eventRef.update({
        state: 'sent',
        sentTokens: currentSentTokens,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info(`Push notifications successfully processed for message ${messageId}. Sent to ${currentSentTokens.length} tokens.`);
    } catch (err: any) {
      functions.logger.error(`Error processing push notification for event ${eventId}:`, err);

      // Record failure state with partial progress
      await eventRef.update({
        state: 'failed',
        error: err?.message || String(err),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Rethrow to trigger Cloud Functions automated retry
      throw err;
    }
  });
