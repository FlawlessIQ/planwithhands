const { Firestore } = require("../functions/node_modules/@google-cloud/firestore");

const db = new Firestore({
  projectId: "plan-with-hands",
  databaseId: "planwithhands",
});

function ts(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

function summarizeToken(token) {
  if (!token || typeof token !== "string") return null;
  return {
    prefix: token.slice(0, 12),
    suffix: token.slice(-8),
    length: token.length,
  };
}

async function main() {
  const userId = process.argv[2];
  const orgId = process.argv[3];
  if (!userId || !orgId) {
    throw new Error("Usage: node scripts/inspectPushState.js <userId> <orgId>");
  }

  const userSnap = await db.collection("users").doc(userId).get();
  const user = userSnap.data() || {};
  console.log(JSON.stringify({
    userId,
    email: user.email || null,
    role: user.role || null,
    preferredLanguageCode: user.preferredLanguageCode || null,
    lastFcmToken: summarizeToken(user.lastFcmToken),
    lastFcmTokenUpdatedAt: ts(user.lastFcmTokenUpdatedAt),
    lastFcmTokenInvalidatedAt: ts(user.lastFcmTokenInvalidatedAt),
    notificationSettings: user.notificationSettings || null,
  }, null, 2));

  const tokensSnap = await db.collection("users").doc(userId).collection("deviceTokens").get();
  console.log(`deviceTokens count=${tokensSnap.size}`);
  tokensSnap.docs.forEach((doc) => {
    const data = doc.data();
    console.log(JSON.stringify({
      id: doc.id,
      fcmToken: summarizeToken(data.fcmToken),
      isActive: data.isActive,
      platform: data.platform || null,
      updatedAt: ts(data.updatedAt),
      invalidatedAt: ts(data.invalidatedAt),
      expiresAt: ts(data.expiresAt),
    }, null, 2));
  });

  const outboxSnap = await db
    .collection("organizations")
    .doc(orgId)
    .collection("notificationOutbox")
    .orderBy("createdAt", "desc")
    .limit(3)
    .get();
  console.log(`latestOutbox count=${outboxSnap.size}`);
  outboxSnap.docs.forEach((doc) => {
    const data = doc.data();
    console.log(JSON.stringify({
      id: doc.id,
      type: data.type || null,
      targetType: data.targetType || null,
      userIds: data.userIds || null,
      title: data.title || null,
      createdAt: ts(data.createdAt),
    }, null, 2));
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
