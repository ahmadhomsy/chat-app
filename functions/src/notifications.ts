import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggers when a new message document is created in a conversation.
 * Sends push notifications to all participants except the sender,
 * and automatically purges invalid or expired FCM tokens.
 *
 * Reliability features:
 * - Event-level idempotency via `_function_events` collection.
 * - Multi-device support with token deduplication.
 * - Handles both `messaging/invalid-registration-token` and
 *   `messaging/registration-token-not-registered`.
 * - Partial failure handling and resilient logging.
 */
export const onNewChatMessage = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const { conversationId, messageId } = context.params;
    const eventId = context.eventId;
    const messageData = snapshot.data();

    if (!messageData) {
      functions.logger.warn(`No data found for message: ${messageId}`);
      return;
    }

    const firestore = admin.firestore();

    // 1. Event-level idempotency check
    const eventRef = firestore.collection('_function_events').doc(eventId);
    try {
      const alreadyProcessed = await firestore.runTransaction(async (transaction) => {
        const eventDoc = await transaction.get(eventRef);
        if (eventDoc.exists) {
          return true;
        }
        transaction.set(eventRef, {
          type: 'onNewChatMessage',
          conversationId,
          messageId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return false;
      });

      if (alreadyProcessed) {
        functions.logger.info(`Event ${eventId} already processed for message ${messageId}. Skipping duplicate.`);
        return;
      }
    } catch (idempotencyError) {
      functions.logger.warn(`Idempotency check failed for event ${eventId}, proceeding cautiously:`, idempotencyError);
    }

    const senderId = messageData.senderId as string;
    const senderName = (messageData.senderName as string) || 'Someone';
    const text = (messageData.text as string) || '';
    const messageType = (messageData.type as string) || 'text';

    try {
      // 2. Fetch parent conversation to identify participants and conversation type
      const conversationDoc = await firestore
        .collection('conversations')
        .doc(conversationId)
        .get();

      if (!conversationDoc.exists) {
        functions.logger.warn(`Parent conversation not found: ${conversationId}`);
        return;
      }

      const conversationData = conversationDoc.data() || {};
      const participantIds: string[] = conversationData.participantIds || [];
      const isGroup = conversationData.type === 'group';
      const groupName = (conversationData.groupName as string) || 'Group Chat';

      // 3. Exclude sender from recipients (guarantee sender never receives their own notification)
      const recipientIds = participantIds.filter((uid) => uid !== senderId);
      if (recipientIds.length === 0) {
        functions.logger.info(`No other participants to notify for conversation: ${conversationId}`);
        return;
      }

      // 4. Collect and deduplicate recipient FCM tokens across all their devices
      interface TokenRecord {
        token: string;
        userId: string;
        docRef: admin.firestore.DocumentReference;
      }

      const tokenRecordMap = new Map<string, TokenRecord>();

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
            // Deduplicate tokens
            if (!tokenRecordMap.has(token)) {
              tokenRecordMap.set(token, {
                token,
                userId: recipientId,
                docRef: doc.ref,
              });
            }
          }
        });
      }

      if (tokenRecordMap.size === 0) {
        functions.logger.info(`No active FCM tokens for recipients of conversation: ${conversationId}`);
        return;
      }

      const tokenRecords = Array.from(tokenRecordMap.values());
      const tokens = tokenRecords.map((t) => t.token);

      // 5. Build notification payload
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

      const multicastMessage: admin.messaging.MulticastMessage = {
        tokens,
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

      // 6. Send multicast message
      const response = await admin.messaging().sendEachForMulticast(multicastMessage);

      // 7. Handle token cleanup for invalid or unregistered tokens
      const deletePromises: Promise<admin.firestore.WriteResult>[] = [];

      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          const errorCode = resp.error.code;
          functions.logger.warn(`FCM delivery failure for token index ${idx}: code=${errorCode}, message=${resp.error.message}`);
          if (
            errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered'
          ) {
            const tokenRecord = tokenRecords[idx];
            if (tokenRecord) {
              deletePromises.push(tokenRecord.docRef.delete());
            }
          }
        }
      });

      if (deletePromises.length > 0) {
        const deleteResults = await Promise.allSettled(deletePromises);
        const successfulDeletes = deleteResults.filter((r) => r.status === 'fulfilled').length;
        functions.logger.info(`Purged ${successfulDeletes}/${deletePromises.length} invalid/unregistered FCM tokens.`);
      }

      functions.logger.info(
        `Push notifications processed for message: ${messageId}. Sent: ${tokens.length}, Success: ${response.successCount}, Failures: ${response.failureCount}`
      );
    } catch (error) {
      functions.logger.error(`Error sending push notifications for message ${messageId}:`, error);
    }
  });
