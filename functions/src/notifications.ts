import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {
  FCM_MULTICAST_CHUNK_SIZE,
  LOCK_LEASE_MS,
  TokenEntry,
  chunkItems,
  evaluateEventLock,
  filterTokensForDispatch,
  isEventExpiredForRetry,
  isRetryableNotificationError,
  processMulticastResponses,
} from './notification_helpers';

export const onNewChatMessage = functions
  .runWith({ failurePolicy: true, timeoutSeconds: 120, memory: '256MB' })
  .firestore.document('conversations/{conversationId}/messages/{messageId}')
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

    // Guard against unbounded retry storm on terminal / stale events (> 10 minutes)
    const eventTimeMs = context.timestamp ? new Date(context.timestamp).getTime() : nowMs;
    if (isEventExpiredForRetry(eventTimeMs, nowMs)) {
      functions.logger.warn(
        `Event ${eventId} exceeded max retry window (${nowMs - eventTimeMs}ms). Marking terminal and aborting.`
      );
      await eventRef.set(
        {
          state: 'failed',
          error: `Terminal failure: exceeded max retry window of 10 minutes`,
          terminal: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt,
        },
        { merge: true }
      );
      return;
    }

    // 1. Concurrency Guard & Lock Lease
    let previouslySentTokens: string[] = [];
    let previouslyFailedTokens: string[] = [];

    const lockAcquired = await firestore.runTransaction(async (transaction) => {
      const eventDoc = await transaction.get(eventRef);
      const evalResult = evaluateEventLock(eventDoc.data(), nowMs, LOCK_LEASE_MS);

      if (!evalResult.canProcess) {
        if (evalResult.reason === 'already_sent') {
          functions.logger.info(`Event ${eventId} already completed. Skipping.`);
        } else {
          functions.logger.info(`Event ${eventId} is currently locked by another invocation.`);
        }
        return false;
      }

      previouslySentTokens = evalResult.previouslySentTokens;
      previouslyFailedTokens = evalResult.permanentlyFailedTokens;

      if (eventDoc.exists) {
        transaction.update(eventRef, {
          state: 'processing',
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
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
      }

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
      const tokensToSend = filterTokensForDispatch(allTokens, previouslySentTokens, previouslyFailedTokens);

      if (tokensToSend.length === 0) {
        functions.logger.info(`All tokens already delivered or permanently failed for message ${messageId}.`);
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
      const chunks = chunkItems(tokensToSend, FCM_MULTICAST_CHUNK_SIZE);
      const currentSentTokens = [...previouslySentTokens];
      const currentFailedTokens = [...previouslyFailedTokens];
      const allInvalidDocRefs: admin.firestore.DocumentReference[] = [];
      const allTransientErrors: { token: string; code: string; message: string }[] = [];

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
        const chunkResults = processMulticastResponses(chunk, response.responses);

        currentSentTokens.push(...chunkResults.newlySentTokens);
        currentFailedTokens.push(...chunkResults.newlyPermanentlyFailedTokens);
        allInvalidDocRefs.push(...chunkResults.invalidDocRefsToDelete);
        allTransientErrors.push(...chunkResults.transientFailures);

        // Persist successful delivery progress and renew lock lease heartbeat
        await eventRef.update({
          sentTokens: currentSentTokens,
          failedTokens: currentFailedTokens,
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // 6. Prune invalid / unregistered tokens from Firestore
      if (allInvalidDocRefs.length > 0) {
        const deletePromises = allInvalidDocRefs.map((ref) => ref.delete());
        const results = await Promise.allSettled(deletePromises);
        const successfulDeletes = results.filter((r) => r.status === 'fulfilled').length;
        functions.logger.info(`Pruned ${successfulDeletes}/${allInvalidDocRefs.length} invalid/unregistered FCM tokens.`);
      }

      // 7. Check if any retryable transient delivery failures occurred
      if (allTransientErrors.length > 0) {
        const errorSummary = `Transient FCM delivery failure for ${allTransientErrors.length} token(s): ${allTransientErrors.map((e) => e.code).join(', ')}`;
        functions.logger.warn(errorSummary);

        // Mark event as failed so retries can resume, and rethrow to trigger Cloud Functions retry
        await eventRef.update({
          state: 'failed',
          error: errorSummary,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        throw new Error(errorSummary);
      }

      // 8. Mark event as completely sent
      await eventRef.update({
        state: 'sent',
        sentTokens: currentSentTokens,
        failedTokens: currentFailedTokens,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info(`Push notifications successfully processed for message ${messageId}. Sent to ${currentSentTokens.length} tokens.`);
    } catch (err: any) {
      functions.logger.error(`Error processing push notification for event ${eventId}:`, err);

      await eventRef.update({
        state: 'failed',
        error: err?.message || String(err),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (isRetryableNotificationError(err)) {
        throw err;
      } else {
        functions.logger.warn(`Terminal non-retryable error for event ${eventId}. Not retrying: ${err?.message}`);
      }
    }
  });
