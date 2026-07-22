
// --- NEW LOOP-PROOF, IDEMPOTENT, KILL-SWITCH ENABLED, TTL-SUPPORTING FUNCTION ---
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Firestore, BulkWriter} from "@google-cloud/firestore";

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

// Helper: Check kill-switch in org settings
async function notificationsEnabled(orgId: string): Promise<boolean> {
  const settingsRef = db.collection("organizations").doc(orgId).collection("settings").doc("general");
  const doc = await settingsRef.get();
  return doc.exists ? doc.data()?.notificationsEnabled !== false : true;
}

// Helper: Idempotency lock
async function acquireEventLock(eventId: string): Promise<boolean> {
  const lockRef = db.collection("_ops").doc("eventLocks").collection("locks").doc(eventId);
  const doc = await lockRef.get();
  if (doc.exists) return false;
  await lockRef.set({ acquiredAt: admin.firestore.FieldValue.serverTimestamp() });
  return true;
}

// Helper: TTL timestamp (30 days)
function getTTLDate(): Date {
  return new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
}

function normalizeLanguageCode(rawValue: unknown): string {
  const normalized = String(rawValue || "").trim().toLowerCase().replace(/_/g, "-");
  if (normalized.startsWith("es")) return "es";
  if (normalized.startsWith("pt")) return "pt";
  return "en";
}

function getLocalizedField(
  notif: FirebaseFirestore.DocumentData,
  field: "title" | "message",
  preferredLanguageCode: string,
): string {
  const fallback = String(notif?.[field] || "");
  const languageMap = notif?.[`${field}ByLanguage`];

  if (languageMap && typeof languageMap === "object") {
    const exact = languageMap[preferredLanguageCode];
    if (typeof exact === "string" && exact.trim().length > 0) return exact;

    const baseCode = preferredLanguageCode.split("-")[0];
    const baseValue = languageMap[baseCode];
    if (typeof baseValue === "string" && baseValue.trim().length > 0) return baseValue;
  }

  return fallback;
}

function isInvalidFcmTokenError(code?: string): boolean {
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token";
}

function timestampMillis(value: unknown): number {
  if (!value) return 0;
  if (value instanceof Date) return value.getTime();

  const timestampLike = value as { toMillis?: () => number };
  if (typeof timestampLike.toMillis === "function") {
    return timestampLike.toMillis();
  }

  return 0;
}

function shouldUseLastFcmToken(userData: FirebaseFirestore.DocumentData): boolean {
  const token = userData.lastFcmToken;
  if (typeof token !== "string" || token.trim().length === 0) return false;

  const updatedAt = timestampMillis(userData.lastFcmTokenUpdatedAt);
  const invalidatedAt = timestampMillis(userData.lastFcmTokenInvalidatedAt);
  return invalidatedAt === 0 || updatedAt >= invalidatedAt;
}

function addTokenRef(
  refsByToken: Map<string, FirebaseFirestore.DocumentReference[]>,
  token: string,
  ref: FirebaseFirestore.DocumentReference,
): void {
  const refs = refsByToken.get(token) || [];
  refs.push(ref);
  refsByToken.set(token, refs);
}

async function deactivateInvalidTokens(
  tokens: Set<string>,
  tokenRefsByToken: Map<string, FirebaseFirestore.DocumentReference[]>,
  fallbackUserRefsByToken: Map<string, FirebaseFirestore.DocumentReference[]>,
): Promise<void> {
  if (tokens.size === 0) return;

  const writer = db.bulkWriter();
  const invalidatedAt = admin.firestore.FieldValue.serverTimestamp();

  for (const token of tokens) {
    const tokenRefs = tokenRefsByToken.get(token) || [];
    tokenRefs.forEach((ref) => {
      writer.set(
        ref,
        {isActive: false, invalidatedAt},
        {merge: true},
      );
    });

    const fallbackUserRefs = fallbackUserRefsByToken.get(token) || [];
    fallbackUserRefs.forEach((ref) => {
      writer.set(
        ref,
        {lastFcmTokenInvalidatedAt: invalidatedAt},
        {merge: true},
      );
    });
  }

  await writer.close();
  console.log(`🧹 [Outbox] Marked ${tokens.size} invalid FCM token(s) inactive`);
}

// Main function: Outbox trigger, fan-out to per-user inbox
export const onNotificationOutboxCreated = functions.firestore
  .database(FIRESTORE_DATABASE_ID)
  .document("organizations/{orgId}/notificationOutbox/{notifId}")
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    const notifId = context.params.notifId;
    const orgId = context.params.orgId;
    if (!notif) return;

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
    let recipientUserIds: string[] = [];
    switch (notif.targetType) {
      case "users":
      case "user_ids": {
        const raw = (notif.userIds || notif.targetIds || notif.userIDs) as any;
        const ids = Array.isArray(raw) ? raw : [];
        recipientUserIds = Array.from(
          new Set(ids.filter((id: any) => typeof id === "string" && id.length > 0))
        );
        console.log(`[Outbox] Targeting explicit user IDs: ${recipientUserIds.length}`);
        break;
      }
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
        } else {
          console.log(`[Outbox] Group ${notif.targetId} not found`);
        }
        break;
      }
      case "location": {
        console.log(`[Outbox] Location targeting for location ${notif.targetId} in org ${orgId}`);
        
        // First try users with locationIds array
        const arraySnap = await db.collection("users")
          .where("organizationId", "==", orgId)
          .where("isActive", "==", true)
          .where("locationIds", "array-contains", notif.targetId)
          .get();
        
        let arrayUserIds = arraySnap.docs.map(doc => doc.id);
        console.log(`[Outbox] Found ${arrayUserIds.length} users with locationIds array containing ${notif.targetId}`);
        
        // Then try users with single locationId field
        const singleSnap = await db.collection("users")
          .where("organizationId", "==", orgId)
          .where("isActive", "==", true)
          .where("locationId", "==", notif.targetId)
          .get();
        
        let singleUserIds = singleSnap.docs.map(doc => doc.id);
        console.log(`[Outbox] Found ${singleUserIds.length} users with locationId field equal to ${notif.targetId}`);
        
        // Combine and deduplicate user IDs
        const allLocationUserIds = [...new Set([...arrayUserIds, ...singleUserIds])];
        recipientUserIds = allLocationUserIds;
        console.log(`[Outbox] Total unique users for location ${notif.targetId}: ${recipientUserIds.length}`);
        
        if (recipientUserIds.length === 0) {
          // Debug: let's check what users exist in this org and their location assignments
          const allUsersSnap = await db.collection("users")
            .where("organizationId", "==", orgId)
            .where("isActive", "==", true)
            .get();
          console.log(`[Outbox] Debug: Found ${allUsersSnap.docs.length} active users in org`);
          allUsersSnap.docs.forEach(doc => {
            const userData = doc.data();
            console.log(`[Outbox] Debug: User ${doc.id} locationIds:`, userData.locationIds || 'none', 'locationId:', userData.locationId || 'none');
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
  const writer: BulkWriter = db.bulkWriter();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    
    // Get FCM tokens for all recipients for push notifications
    const tokenPromises = recipientUserIds.map(async (userId: string) => {
      try {
        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data() || {};
        const userRef = userDoc.ref;
        const preferredLanguageCode = normalizeLanguageCode(
          userData.preferredLanguageCode,
        );
        const tokenRefsByToken = new Map<string, FirebaseFirestore.DocumentReference[]>();
        const fallbackUserRefsByToken = new Map<string, FirebaseFirestore.DocumentReference[]>();

        // First try user-specific subcollection (new format)
        const userTokenSnap = await db
          .collection("users")
          .doc(userId)
          .collection("deviceTokens")
          .where("isActive", "==", true)
          .get();

        let tokens: string[] = [];
        if (!userTokenSnap.empty) {
          tokens = userTokenSnap.docs
            .map((doc) => {
              const fcmToken = doc.data().fcmToken;
              if (typeof fcmToken === "string" && fcmToken.trim().length > 0) {
                addTokenRef(tokenRefsByToken, fcmToken, doc.ref);
                return fcmToken;
              }
              return "";
            })
            .filter(Boolean);
        } else {
          // Fallback to legacy top-level collection
          const legacyTokenSnap = await db
            .collection("deviceTokens")
            .where("userId", "==", userId)
            .where("isActive", "==", true)
            .get();
          tokens = legacyTokenSnap.docs
            .map((doc) => {
              const fcmToken = doc.data().fcmToken;
              if (typeof fcmToken === "string" && fcmToken.trim().length > 0) {
                addTokenRef(tokenRefsByToken, fcmToken, doc.ref);
                return fcmToken;
              }
              return "";
            })
            .filter(Boolean);
        }

        if (tokens.length === 0 && shouldUseLastFcmToken(userData)) {
          tokens = [userData.lastFcmToken];
          addTokenRef(fallbackUserRefsByToken, userData.lastFcmToken, userRef);
          console.log(`[Outbox] Using lastFcmToken fallback for user ${userId}`);
        }

        return {
          userId,
          preferredLanguageCode,
          tokens: tokens.filter(Boolean),
          tokenRefsByToken,
          fallbackUserRefsByToken,
        };
      } catch (error) {
        console.error(`Error fetching tokens for user ${userId}:`, error);
        return {
          userId,
          preferredLanguageCode: "en",
          tokens: [],
          tokenRefsByToken: new Map<string, FirebaseFirestore.DocumentReference[]>(),
          fallbackUserRefsByToken: new Map<string, FirebaseFirestore.DocumentReference[]>(),
        };
      }
    });

    const userTokens = await Promise.all(tokenPromises);
    const userMeta = new Map(
      userTokens.map((entry) => [entry.userId, entry]),
    );
    const tokenRefsByToken = new Map<string, FirebaseFirestore.DocumentReference[]>();
    const fallbackUserRefsByToken = new Map<string, FirebaseFirestore.DocumentReference[]>();
    userTokens.forEach((entry) => {
      entry.tokenRefsByToken.forEach((refs, token) => {
        refs.forEach((ref) => addTokenRef(tokenRefsByToken, token, ref));
      });
      entry.fallbackUserRefsByToken.forEach((refs, token) => {
        refs.forEach((ref) => addTokenRef(fallbackUserRefsByToken, token, ref));
      });
    });

    // Flatten and de-duplicate tokens to avoid duplicate sends
    const tokenSet = new Set<string>();
    userTokens.forEach(({tokens}) => {
      for (const t of tokens) tokenSet.add(t);
    });
    const allTokens: string[] = Array.from(tokenSet);

    // Write inbox notifications
    for (const userId of recipientUserIds) {
      const preferredLanguageCode =
        userMeta.get(userId)?.preferredLanguageCode || "en";
      const inboxRef = db.collection("userNotifications").doc(userId)
        .collection("notifications").doc();
      writer.set(inboxRef, {
        userId,
        orgId,
        type: notif.type || "general",
        title:
          getLocalizedField(notif, "title", preferredLanguageCode) ||
          "Notification",
        message:
          getLocalizedField(notif, "message", preferredLanguageCode) || "",
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
      console.log(`🔔 [Outbox] Preparing to send push notifications to ${allTokens.length} unique tokens`);
      const tokenGroups = new Map<string, string[]>();
      for (const entry of userTokens) {
        const languageCode = entry.preferredLanguageCode || "en";
        const existingTokens = tokenGroups.get(languageCode) || [];
        for (const token of entry.tokens) {
          if (!existingTokens.includes(token)) {
            existingTokens.push(token);
          }
        }
        tokenGroups.set(languageCode, existingTokens);
      }

      // FCM enforces a 500-token limit per multicast send. Chunk accordingly.
      const chunkSize = 500;
      let totalSuccess = 0;
      let totalFailure = 0;
      const invalidTokens = new Set<string>();

      for (const [languageCode, tokens] of tokenGroups.entries()) {
        const notificationType =
          typeof notif.type === "string" && notif.type.trim().length > 0 ?
            notif.type :
            "general_notification";
        const baseMessage = {
          notification: {
            title:
              getLocalizedField(notif, "title", languageCode) ||
              "Hands Notification",
            body: getLocalizedField(notif, "message", languageCode) || "",
          },
          data: {
            type: notificationType,
            orgId: orgId,
            outboxId: notifId,
            languageCode,
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                sound: "default" as const,
                badge: 1,
              },
            },
          },
          android: {
            notification: {
              channelId: notificationType === "daily_summary" ?
                "daily_summary" :
                "general_notifications",
            },
          },
        };

        for (let i = 0; i < tokens.length; i += chunkSize) {
          const chunk = tokens.slice(i, i + chunkSize);
          const fcmMessage = { ...baseMessage, tokens: chunk };
          try {
            // Use sendEachForMulticast to avoid deprecated legacy /batch endpoint.
            const response = await admin.messaging().sendEachForMulticast(
              fcmMessage,
            );
            totalSuccess += response.successCount;
            totalFailure += response.failureCount;

            // Log up to first 3 errors in this chunk for diagnostics
            const sampleErrors = response.responses
              .map((r, idx) => ({ idx, error: r.error }))
              .filter((x) => !!x.error)
              .slice(0, 3);
            response.responses.forEach((result, idx) => {
              if (isInvalidFcmTokenError(result.error?.code)) {
                invalidTokens.add(chunk[idx]);
              }
            });
            if (sampleErrors.length > 0) {
              console.warn(
                `⚠️ [Outbox] ${languageCode} chunk ${Math.floor(i / chunkSize) + 1}: sample errors:`,
                sampleErrors.map(e => ({ index: e.idx, code: e.error?.code, message: e.error?.message })),
              );
            }
          } catch (error: any) {
            totalFailure += chunk.length;
            console.error(`❌ [Outbox] Error sending ${languageCode} chunk ${Math.floor(i / chunkSize) + 1}:`, {
              message: error?.message,
              code: error?.code,
              stack: error?.stack,
            });
          }
        }
      }

      try {
        await deactivateInvalidTokens(
          invalidTokens,
          tokenRefsByToken,
          fallbackUserRefsByToken,
        );
      } catch (error) {
        console.error("🧹 [Outbox] Failed to mark invalid FCM tokens inactive:", error);
      }
      console.log(`✅ [Outbox] Push notifications summary: ${totalSuccess} successful, ${totalFailure} failed`);
    } else {
      console.log(`📱 [Outbox] No FCM tokens found for push notifications`);
    }
    
    console.log(`[Outbox] Fan-out complete for ${recipientUserIds.length} users.`);
  });
