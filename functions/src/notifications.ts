import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Triggers when a new message document is created in a conversation.
 * Sends push notifications to all participants except the sender,
 * and automatically purges invalid or expired FCM tokens.
 */
export const onNewChatMessage = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const { conversationId, messageId } = context.params;
    const messageData = snapshot.data();

    if (!messageData) {
      functions.logger.warn(`No data found for message: ${messageId}`);
      return;
    }

    const senderId = messageData.senderId as string;
    const senderName = (messageData.senderName as string) || 'Someone';
    const text = (messageData.text as string) || '';
    const messageType = (messageData.type as string) || 'text';

    try {
      // 1. Fetch parent conversation to identify participants and conversation type
      const conversationDoc = await admin.firestore()
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

      // 2. Exclude sender from recipients
      const recipientIds = participantIds.filter((uid) => uid !== senderId);
      if (recipientIds.length === 0) {
        return;
      }

      // 3. Collect recipient FCM tokens
      interface TokenRecord {
        token: string;
        userId: string;
        docRef: admin.firestore.DocumentReference;
      }

      const tokenRecords: TokenRecord[] = [];

      for (const recipientId of recipientIds) {
        const tokensSnapshot = await admin.firestore()
          .collection('users')
          .doc(recipientId)
          .collection('fcmTokens')
          .get();

        tokensSnapshot.forEach((doc) => {
          const data = doc.data();
          if (data && data.token) {
            tokenRecords.push({
              token: data.token,
              userId: recipientId,
              docRef: doc.ref,
            });
          }
        });
      }

      if (tokenRecords.length === 0) {
        functions.logger.info(`No active FCM tokens for recipients of conversation: ${conversationId}`);
        return;
      }

      // 4. Build notification payload
      const title = isGroup ? `${senderName} (${groupName})` : senderName;
      let bodyPreview = text;
      if (messageType === 'image') {
        bodyPreview = '📷 Sent an image';
      } else if (messageType === 'file') {
        bodyPreview = '📎 Sent an attachment';
      }

      // Truncate long preview
      if (bodyPreview.length > 100) {
        bodyPreview = `${bodyPreview.substring(0, 97)}...`;
      }

      const tokens = tokenRecords.map((t) => t.token);

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

      // 5. Send multicast message
      const response = await admin.messaging().sendEachForMulticast(multicastMessage);

      // 6. Handle token cleanup for invalid/expired tokens
      const tokensToDelete: Promise<admin.firestore.WriteResult>[] = [];

      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          const errorCode = resp.error.code;
          if (
            errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered'
          ) {
            const tokenRecord = tokenRecords[idx];
            if (tokenRecord) {
              tokensToDelete.push(tokenRecord.docRef.delete());
            }
          }
        }
      });

      if (tokensToDelete.length > 0) {
        await Promise.all(tokensToDelete);
        functions.logger.info(`Purged ${tokensToDelete.length} expired or invalid FCM tokens.`);
      }

      functions.logger.info(
        `Push notifications processed for message: ${messageId}. Success: ${response.successCount}, Failed: ${response.failureCount}`
      );
    } catch (error) {
      functions.logger.error(`Error sending push notifications for message ${messageId}:`, error);
    }
  });
