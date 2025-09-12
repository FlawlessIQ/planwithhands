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
exports.onNotificationOutboxCreated = void 0;
// --- NEW LOOP-PROOF, IDEMPOTENT, KILL-SWITCH ENABLED, TTL-SUPPORTING FUNCTION ---
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
if (!admin.apps.length) {
    admin.initializeApp();
}
// Helper: Check kill-switch in org settings
async function notificationsEnabled(orgId) {
    const settingsRef = db.collection("organizations").doc(orgId).collection("settings").doc("general");
    const doc = await settingsRef.get();
    return doc.exists ? doc.data()?.notificationsEnabled !== false : true;
}
// Helper: Idempotency lock
async function acquireEventLock(eventId) {
    const lockRef = db.collection("_ops").doc("eventLocks").collection("locks").doc(eventId);
    const doc = await lockRef.get();
    if (doc.exists)
        return false;
    await lockRef.set({ acquiredAt: admin.firestore.FieldValue.serverTimestamp() });
    return true;
}
// Helper: TTL timestamp (30 days)
function getTTLDate() {
    return new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
}
// Main function: Outbox trigger, fan-out to per-user inbox
exports.onNotificationOutboxCreated = functions.firestore
    .database(FIRESTORE_DATABASE_ID)
    .document("organizations/{orgId}/notificationOutbox/{notifId}")
    .onCreate(async (snap, context) => {
    const notif = snap.data();
    const notifId = context.params.notifId;
    const orgId = context.params.orgId;
    if (!notif)
        return;
    // Kill-switch check
    if (!(await notificationsEnabled(orgId))) {
        console.log(`[KillSwitch] Notifications disabled for org ${orgId}`);
        return;
    }
    // Idempotency lock
    const eventLockId = `${orgId}_${notifId}`;
    if (!(await acquireEventLock(eventLockId))) {
        console.log(`[Idempotency] Event ${eventLockId} already processed.`);
        return;
    }
    // Determine recipients
    let recipientUserIds = [];
    switch (notif.targetType) {
        case "all":
        case "all_users": {
            const snap = await db.collection("users")
                .where("organizationId", "==", orgId)
                .where("isActive", "==", true)
                .get();
            recipientUserIds = snap.docs.map(doc => doc.id);
            break;
        }
        case "group": {
            const groupDoc = await db.collection("organizations").doc(orgId)
                .collection("groups").doc(notif.targetId).get();
            if (groupDoc.exists) {
                const groupData = groupDoc.data();
                recipientUserIds = groupData?.memberIds || groupData?.userIds || [];
                console.log(`[Outbox] Group ${notif.targetId} has ${recipientUserIds.length} members:`, recipientUserIds);
            }
            else {
                console.log(`[Outbox] Group ${notif.targetId} not found`);
            }
            break;
        }
        case "location": {
            console.log(`[Outbox] Location targeting for location ${notif.targetId} in org ${orgId}`);
            const snap = await db.collection("users")
                .where("organizationId", "==", orgId)
                .where("isActive", "==", true)
                .where("locationIds", "array-contains", notif.targetId)
                .get();
            recipientUserIds = snap.docs.map(doc => doc.id);
            console.log(`[Outbox] Location ${notif.targetId} has ${recipientUserIds.length} users:`, recipientUserIds);
            if (recipientUserIds.length === 0) {
                // Debug: let's check what users exist in this org and their locationIds
                const allUsersSnap = await db.collection("users")
                    .where("organizationId", "==", orgId)
                    .where("isActive", "==", true)
                    .get();
                console.log(`[Outbox] Debug: Found ${allUsersSnap.docs.length} active users in org`);
                allUsersSnap.docs.forEach(doc => {
                    const userData = doc.data();
                    console.log(`[Outbox] Debug: User ${doc.id} locationIds:`, userData.locationIds || 'none');
                });
            }
            break;
        }
        default:
            console.log(`[Outbox] Unknown targetType: ${notif.targetType}`);
            return;
    }
    if (recipientUserIds.length === 0) {
        console.log(`[Outbox] No recipients for notification ${notifId}`);
        return;
    }
    // Fan-out: Write to per-user inbox with TTL and send push notifications
    const writer = db.bulkWriter();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    // Get FCM tokens for all recipients for push notifications
    const tokenPromises = recipientUserIds.map(async (userId) => {
        try {
            // First try user-specific subcollection (new format)
            const userTokenSnap = await db
                .collection("users")
                .doc(userId)
                .collection("deviceTokens")
                .where("isActive", "==", true)
                .get();
            let tokens = [];
            if (!userTokenSnap.empty) {
                tokens = userTokenSnap.docs.map((doc) => doc.data().fcmToken);
            }
            else {
                // Fallback to legacy top-level collection
                const legacyTokenSnap = await db
                    .collection("deviceTokens")
                    .where("userId", "==", userId)
                    .where("isActive", "==", true)
                    .get();
                tokens = legacyTokenSnap.docs.map((doc) => doc.data().fcmToken);
            }
            return { userId, tokens: tokens.filter(Boolean) };
        }
        catch (error) {
            console.error(`Error fetching tokens for user ${userId}:`, error);
            return { userId, tokens: [] };
        }
    });
    const userTokens = await Promise.all(tokenPromises);
    const allTokens = [];
    userTokens.forEach(({ tokens }) => {
        allTokens.push(...tokens);
    });
    // Write inbox notifications
    for (const userId of recipientUserIds) {
        const inboxRef = db.collection("userNotifications").doc(userId)
            .collection("notifications").doc();
        writer.set(inboxRef, {
            userId,
            orgId,
            type: notif.type || "general",
            title: notif.title || "Notification",
            message: notif.message || "",
            readBy: [],
            archivedBy: [],
            createdAt: timestamp,
            targetType: notif.targetType,
            ...(notif.targetId && { targetId: notif.targetId }),
            expiresAt: getTTLDate(),
            outboxId: notifId,
        });
    }
    await writer.close();
    // Send push notifications if we have tokens
    if (allTokens.length > 0) {
        console.log(`🔔 [Outbox] Sending push notifications to ${allTokens.length} tokens`);
        const fcmMessage = {
            notification: {
                title: notif.title || "Hands Notification",
                body: notif.message || "",
            },
            data: {
                type: "general_notification",
                orgId: orgId,
                outboxId: notifId,
            },
            tokens: allTokens,
        };
        try {
            const response = await admin.messaging().sendMulticast(fcmMessage);
            console.log(`✅ [Outbox] Push notifications sent: ${response.successCount} successful, ${response.failureCount} failed`);
        }
        catch (error) {
            console.error(`❌ [Outbox] Error sending push notifications:`, error);
        }
    }
    else {
        console.log(`📱 [Outbox] No FCM tokens found for push notifications`);
    }
    console.log(`[Outbox] Fan-out complete for ${recipientUserIds.length} users.`);
});
