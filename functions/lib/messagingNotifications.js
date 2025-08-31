"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onGeneralNotificationCreated = exports.sendMessageNotification = exports.onMessageCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Trigger when a new message is created in a thread
 * Sends push notifications to all recipients in the thread
 */
exports.onMessageCreated = functions.firestore
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
        const threadData = threadDoc.data();
        const recipientUserIds = threadData.recipientUserIds || [];
        const orgId = threadData.orgId;
        // Filter out the sender from recipients
        const actualRecipients = recipientUserIds.filter((id) => id !== senderId);
        if (actualRecipients.length === 0) {
            console.log("No recipients to notify");
            return;
        }
        console.log(`Notifying ${actualRecipients.length} recipients`);
        // Get FCM tokens for recipients
        const tokenPromises = actualRecipients.map(async (userId) => {
            const tokenSnap = await admin.firestore()
                .collection("deviceTokens")
                .where("userId", "==", userId)
                .where("isActive", "==", true)
                .get();
            const tokens = tokenSnap.docs.map((doc) => doc.data().fcmToken);
            return { userId, tokens };
        });
        const userTokens = await Promise.all(tokenPromises);
        const allTokens = [];
        userTokens.forEach(({ tokens }) => {
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
            const invalidTokens = [];
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
    }
    catch (error) {
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
exports.sendMessageNotification = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const { threadId, messageText, recipientUserIds } = data;
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
        const actualRecipients = recipients.filter((id) => id !== senderId);
        if (actualRecipients.length === 0) {
            return { success: true, message: "No recipients to notify" };
        }
        // Get FCM tokens
        const tokenPromises = actualRecipients.map(async (userId) => {
            const tokenSnap = await admin.firestore()
                .collection("deviceTokens")
                .where("userId", "==", userId)
                .where("isActive", "==", true)
                .get();
            return tokenSnap.docs.map((doc) => doc.data().fcmToken);
        });
        const userTokenArrays = await Promise.all(tokenPromises);
        const allTokens = userTokenArrays.flat();
        if (allTokens.length === 0) {
            return { success: true, message: "No FCM tokens found" };
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
    }
    catch (error) {
        console.error("Error in sendMessageNotification:", error);
        throw new functions.https.HttpsError("internal", "Failed to send notification");
    }
});
/**
 * Helper function to clean up invalid FCM tokens
 * @param {string[]} invalidTokens - Array of invalid token strings
 * @return {Promise<void>}
 */
async function cleanupInvalidTokens(invalidTokens) {
    if (invalidTokens.length === 0)
        return;
    try {
        const batch = admin.firestore().batch();
        for (const token of invalidTokens) {
            const tokenQuery = await admin.firestore()
                .collection("deviceTokens")
                .where("token", "==", token)
                .get();
            tokenQuery.docs.forEach((doc) => {
                batch.update(doc.ref, { isActive: false });
            });
        }
        await batch.commit();
        console.log(`Marked ${invalidTokens.length} tokens as inactive`);
    }
    catch (error) {
        console.error("Error cleaning up invalid tokens:", error);
    }
}
/**
 * Trigger when a new general notification is created
 * Sends push notifications to targeted recipients based on notification type
 */
exports.onGeneralNotificationCreated = functions.firestore
    .document("organizations/{orgId}/notifications/{notifId}")
    .onCreate(async (snap, context) => {
    const notification = snap.data();
    const notifId = context.params.notifId;
    const orgId = context.params.orgId;
    try {
        console.log(`Processing general notification: ${notifId} in org: ${orgId}`);
        // Skip if this is a user-specific notification (already has userId)
        if (notification.userId) {
            console.log("Skipping user-specific notification - already processed");
            return;
        }
        const targetType = notification.targetType;
        const targetId = notification.targetId;
        let recipientUserIds = [];
        // Determine recipients based on target type
        switch (targetType) {
            case 'all':
                // Get all active users in the organization
                const allUsersSnap = await admin.firestore()
                    .collection("users")
                    .where("organizationId", "==", orgId)
                    .where("isActive", "==", true)
                    .get();
                recipientUserIds = allUsersSnap.docs.map(doc => doc.id);
                break;
            case 'group':
                // Get users in the specified group
                const groupDoc = await admin.firestore()
                    .collection("organizations")
                    .doc(orgId)
                    .collection("groups")
                    .doc(targetId)
                    .get();
                if (groupDoc.exists) {
                    const groupData = groupDoc.data();
                    recipientUserIds = groupData?.userIds || [];
                }
                break;
            case 'location':
                // Get users assigned to the specified location
                const locationUsersSnap = await admin.firestore()
                    .collection("users")
                    .where("organizationId", "==", orgId)
                    .where("isActive", "==", true)
                    .where("locationIds", "array-contains", targetId)
                    .get();
                recipientUserIds = locationUsersSnap.docs.map(doc => doc.id);
                break;
            default:
                console.log(`Unknown target type: ${targetType}`);
                return;
        }
        if (recipientUserIds.length === 0) {
            console.log("No recipients found for notification");
            return;
        }
        console.log(`Notifying ${recipientUserIds.length} recipients for ${targetType} notification`);
        // Get FCM tokens for recipients
        const tokenPromises = recipientUserIds.map(async (userId) => {
            const tokenSnap = await admin.firestore()
                .collection("deviceTokens")
                .where("userId", "==", userId)
                .where("isActive", "==", true)
                .get();
            const tokens = tokenSnap.docs.map((doc) => doc.data().fcmToken);
            return { userId, tokens };
        });
        const userTokens = await Promise.all(tokenPromises);
        const allTokens = [];
        userTokens.forEach(({ tokens }) => {
            allTokens.push(...tokens);
        });
        if (allTokens.length === 0) {
            console.log("No FCM tokens found for recipients");
            return;
        }
        // Create notification documents for each recipient
        const batch = admin.firestore().batch();
        const timestamp = admin.firestore.FieldValue.serverTimestamp();
        for (const userId of recipientUserIds) {
            const userNotificationRef = admin.firestore()
                .collection("organizations")
                .doc(orgId)
                .collection("notifications")
                .doc();
            batch.set(userNotificationRef, {
                userId: userId,
                orgId: orgId,
                type: "general",
                title: notification.title || "Notification",
                message: notification.message || "",
                read: false,
                createdAt: timestamp,
                targetType: targetType,
                targetId: targetId,
                // Add TTL - notifications expire after 30 days
                expiresAt: new Date(Date.now() + (30 * 24 * 60 * 60 * 1000)),
            });
        }
        await batch.commit();
        // Prepare FCM message
        const fcmMessage = {
            notification: {
                title: notification.title || "Hands App",
                body: notification.message || "",
            },
            data: {
                type: "general",
                notificationId: notifId,
                orgId: orgId,
                targetType: targetType,
                targetId: targetId || "",
            },
            tokens: allTokens,
        };
        // Send push notifications
        const response = await admin.messaging().sendMulticast(fcmMessage);
        console.log(`General push notifications sent: ${response.successCount} successful, ${response.failureCount} failed`);
        // Clean up invalid tokens
        if (response.responses) {
            const invalidTokens = [];
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
    }
    catch (error) {
        console.error("Error processing general notification:", error);
        throw error;
    }
});
