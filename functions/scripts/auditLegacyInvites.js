/* eslint-disable no-console */
const {admin, db} = require("../firebase_config");

async function main() {
  console.log("Auditing legacy invite and onboarding records...");

  const invitesSnap = await db.collection("invites").get();
  const usersSnap = await db.collection("users").get();

  const usersByOrgAndEmail = new Map();
  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    const email = String(
        data.email || data.userEmail || data.emailAddress || "",
    ).trim().toLowerCase();
    const orgId = String(data.organizationId || "").trim();
    if (!email || !orgId) continue;
    usersByOrgAndEmail.set(`${orgId}::${email}`, {
      id: doc.id,
      onboardingComplete: data.onboardingComplete,
      setupCompleted: data.setupCompleted,
      createdAt: data.createdAt || null,
    });
  }

  const findings = {
    legacyInviteShape: [],
    activeInviteHasExistingUser: [],
    acceptedInviteMissingAcceptedUser: [],
    onboardingIncompleteWithoutActiveInvite: [],
  };

  for (const doc of invitesSnap.docs) {
    const data = doc.data() || {};
    const orgId = String(data.organizationId || "").trim();
    const email = String(data.email || data.emailLower || "").trim().toLowerCase();
    const status = String(data.status || "pending");
    const inviteVersion = data.inviteVersion || null;
    const key = `${orgId}::${email}`;

    if (!inviteVersion || !data.inviteUrl || data.emailLower == null) {
      findings.legacyInviteShape.push({
        inviteId: doc.id,
        orgId,
        email,
        status,
      });
    }

    if (["pending", "sent", "opened"].includes(status) && usersByOrgAndEmail.has(key)) {
      findings.activeInviteHasExistingUser.push({
        inviteId: doc.id,
        orgId,
        email,
        status,
        userId: usersByOrgAndEmail.get(key).id,
      });
    }

    if (status === "accepted" && !data.acceptedUserId) {
      findings.acceptedInviteMissingAcceptedUser.push({
        inviteId: doc.id,
        orgId,
        email,
      });
    }
  }

  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    const email = String(
        data.email || data.userEmail || data.emailAddress || "",
    ).trim().toLowerCase();
    const orgId = String(data.organizationId || "").trim();
    const onboardingComplete = data.onboardingComplete === true;

    if (!email || !orgId || onboardingComplete) {
      continue;
    }

    const activeInvite = invitesSnap.docs.find((inviteDoc) => {
      const invite = inviteDoc.data() || {};
      const inviteEmail = String(invite.email || invite.emailLower || "").trim().toLowerCase();
      const inviteOrgId = String(invite.organizationId || "").trim();
      const inviteStatus = String(invite.status || "pending");
      return inviteEmail === email &&
        inviteOrgId === orgId &&
        ["pending", "sent", "opened"].includes(inviteStatus);
    });

    if (!activeInvite) {
      findings.onboardingIncompleteWithoutActiveInvite.push({
        userId: doc.id,
        orgId,
        email,
      });
    }
  }

  console.log(JSON.stringify(findings, null, 2));
  console.log("Audit complete.");
  await admin.app().delete();
}

main().catch(async (error) => {
  console.error("Audit failed:", error);
  try {
    await admin.app().delete();
  } catch (_) {
    // ignore
  }
  process.exitCode = 1;
});
