import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Trigger when a new message is created in a thread
 * Sends push notifications to all recipients in the thread
 */
export const onMessageCreated = functions.firestore
    .document("messageThreads/{threadId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      const message = snap.data();
      const threadId = context.params.threadId;
      const messageId = context.params.messageId;

      try {
        console.log(`Processing new message: ${messageId} in thread: ${threadId}`);

        // Get the sender's information
        const senderId = message.senderId;
        const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
        const senderData = senderDoc.data();
        const senderName = `${senderData?.firstName || ""} ${senderData?.lastName || ""}`.trim() || "Someone";

        // Get thread details to find recipients
        const threadDoc = await admin.firestore()
            .collection("messageThreads")
            .doc(threadId)
            .get();

        if (!threadDoc.exists) {
          console.error(`Thread ${threadId} not found`);
          return;
        }

        const threadData = threadDoc.data()!;
        const recipientUserIds = threadData.recipientUserIds || [];
        const orgId = threadData.orgId;

        // Filter out the sender from recipients
        const actualRecipients = recipientUserIds.filter((id: string) => id !== senderId);

        if (actualRecipients.length === 0) {
          console.log("No recipients to notify");
          return;
        }

        console.log(`Notifying ${actualRecipients.length} recipients`);

        // Get FCM tokens for recipients
        const tokenPromises = actualRecipients.map(async (userId: string) => {
          const tokenSnap = await admin.firestore()
              .collection("deviceTokens")
              .where("userId", "==", userId)
              .where("isActive", "==", true)
              .get();

          const tokens = tokenSnap.docs.map((doc) => doc.data().token);
          return {userId, tokens};
        });

        const userTokens = await Promise.all(tokenPromises);
        const allTokens: string[] = [];

        userTokens.forEach(({tokens}) => {
          allTokens.push(...tokens);
        });

        if (allTokens.length === 0) {
          console.log("No FCM tokens found for recipients");
          return;
        }

        // Create notification documents for each recipient
        const batch = admin.firestore().batch();
        const timestamp = admin.firestore.FieldValue.serverTimestamp();

        for (const userId of actualRecipients) {
          const notificationRef = admin.firestore()
              .collection("organizations")
              .doc(orgId)
              .collection("notifications")
              .doc();

          batch.set(notificationRef, {
            userId: userId,
            orgId: orgId,
            threadId: threadId,
            type: "message",
            title: `${senderName}`,
            message: message.text.length > 100 ? `${message.text.substring(0, 100)}...` : message.text,
            read: false,
            createdAt: timestamp,
            senderId: senderId,
            senderName: senderName,
            // Add TTL - notifications expire after 30 days
            expiresAt: new Date(Date.now() + (30 * 24 * 60 * 60 * 1000)),
          });
        }

        await batch.commit();

        // Prepare FCM message
        const messageText = message.text.length > 100 ? `${message.text.substring(0, 100)}...` : message.text;

        const fcmMessage = {
          notification: {
            title: senderName,
            body: messageText,
          },
          data: {
            type: "message",
            threadId: threadId,
            messageId: messageId,
            senderId: senderId,
            senderName: senderName,
            orgId: orgId,
          },
          tokens: allTokens,
        };

        // Send push notifications
        const response = await admin.messaging().sendMulticast(fcmMessage);

        console.log(`Push notifications sent: ${response.successCount} successful, ${response.failureCount} failed`);

        // Clean up invalid tokens
        if (response.responses) {
          const invalidTokens: string[] = [];
          response.responses.forEach((resp, index) => {
            if (!resp.success &&
              (resp.error?.code === "messaging/registration-token-not-registered" ||
               resp.error?.code === "messaging/invalid-registration-token")) {
              invalidTokens.push(allTokens[index]);
            }
          });

          if (invalidTokens.length > 0) {
            console.log(`Cleaning up ${invalidTokens.length} invalid tokens`);
            await cleanupInvalidTokens(invalidTokens);
          }
        }
      } catch (error) {
        console.error("Error processing message notification:", error);
        throw error;
      }
    });

/**
 * Callable function to send a message and trigger notifications
 * This provides an alternative to the Firestore trigger
 * @param {object} data - Function call data
 * @param {object} context - Function call context
 * @return {Promise<object>} - Result of the operation
 */
export const sendMessageNotification = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }

  const {threadId, messageText, recipientUserIds} = data;
  const senderId = context.auth.uid;

  if (!threadId || !messageText) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
  }

  try {
    // Get sender information
    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderData = senderDoc.data();
    const senderName = `${senderData?.firstName || ""} ${senderData?.lastName || ""}`.trim() || "Someone";

    // Get thread information
    const threadDoc = await admin.firestore().collection("messageThreads").doc(threadId).get();
    const threadData = threadDoc.data();
    const orgId = threadData?.orgId;

    if (!orgId) {
      throw new functions.https.HttpsError("not-found", "Organization not found");
    }

    // Use provided recipient list or get from thread
    const recipients = recipientUserIds || threadData?.recipientUserIds || [];
    const actualRecipients = recipients.filter((id: string) => id !== senderId);

    if (actualRecipients.length === 0) {
      return {success: true, message: "No recipients to notify"};
    }

    // Get FCM tokens
    const tokenPromises = actualRecipients.map(async (userId: string) => {
      const tokenSnap = await admin.firestore()
          .collection("deviceTokens")
          .where("userId", "==", userId)
          .where("isActive", "==", true)
          .get();

      return tokenSnap.docs.map((doc) => doc.data().token);
    });

    const userTokenArrays = await Promise.all(tokenPromises);
    const allTokens = userTokenArrays.flat();

    if (allTokens.length === 0) {
      return {success: true, message: "No FCM tokens found"};
    }

    // Create notification documents
    const batch = admin.firestore().batch();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    for (const userId of actualRecipients) {
      const notificationRef = admin.firestore()
          .collection("organizations")
          .doc(orgId)
          .collection("notifications")
          .doc();

      batch.set(notificationRef, {
        userId: userId,
        orgId: orgId,
        threadId: threadId,
        type: "message",
        title: senderName,
        message: messageText.length > 100 ? `${messageText.substring(0, 100)}...` : messageText,
        read: false,
        createdAt: timestamp,
        senderId: senderId,
        senderName: senderName,
        expiresAt: new Date(Date.now() + (30 * 24 * 60 * 60 * 1000)),
      });
    }

    await batch.commit();

    // Send push notification
    const fcmMessage = {
      notification: {
        title: senderName,
        body: messageText.length > 100 ? `${messageText.substring(0, 100)}...` : messageText,
      },
      data: {
        type: "message",
        threadId: threadId,
        senderId: senderId,
        senderName: senderName,
        orgId: orgId,
      },
      tokens: allTokens,
    };

    const response = await admin.messaging().sendMulticast(fcmMessage);

    return {
      success: true,
      sent: response.successCount,
      failed: response.failureCount,
      recipients: actualRecipients.length,
    };
  } catch (error) {
    console.error("Error in sendMessageNotification:", error);
    throw new functions.https.HttpsError("internal", "Failed to send notification");
  }
});

/**
 * Helper function to clean up invalid FCM tokens
 * @param {string[]} invalidTokens - Array of invalid token strings
 * @return {Promise<void>}
 */
async function cleanupInvalidTokens(invalidTokens: string[]): Promise<void> {
  if (invalidTokens.length === 0) return;

  try {
    const batch = admin.firestore().batch();

    for (const token of invalidTokens) {
      const tokenQuery = await admin.firestore()
          .collection("deviceTokens")
          .where("token", "==", token)
          .get();

      tokenQuery.docs.forEach((doc) => {
        batch.update(doc.ref, {isActive: false});
      });
    }

    await batch.commit();
    console.log(`Marked ${invalidTokens.length} tokens as inactive`);
  } catch (error) {
    console.error("Error cleaning up invalid tokens:", error);
  }
}
