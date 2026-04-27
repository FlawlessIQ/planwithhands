const {admin, db} = require("./firebase_config");
const {logger} = require("firebase-functions");
const functions = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

const INVITE_TTL_DAYS = 7;
const ACTIVE_INVITE_STATUSES = ["pending", "sent", "opened"];

function getSendGridApiKey() {
  try {
    return process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY;
  } catch (error) {
    logger.warn("Error reading SendGrid configuration:", error.message);
    return process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY;
  }
}

function getSendGridFromEmail() {
  return process.env.SENDGRID_FROM_EMAIL || "noreply@planwithhands.com";
}

function getSendGridFromName() {
  return process.env.SENDGRID_FROM_NAME || "Hands App";
}

function getBaseAppUrl() {
  return process.env.HANDS_APP_BASE_URL || "https://plan-with-hands.web.app";
}

function escapeHtml(value) {
  return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function coerceStringArray(value) {
  if (Array.isArray(value)) {
    return value.map((item) => String(item)).filter(Boolean);
  }
  if (value == null || value === "") {
    return [];
  }
  return [String(value)];
}

function coerceRole(value) {
  if (typeof value === "number") {
    return value;
  }
  return Number.parseInt(String(value || "0"), 10) || 0;
}

function roleLabel(userRole) {
  if (userRole === 2) return "Admin";
  if (userRole === 1) return "Manager";
  return "Staff";
}

function roleKey(userRole) {
  if (userRole === 2) return "admin";
  if (userRole === 1) return "manager";
  return "member";
}

function normalizePreferredLanguageCode(value) {
  const normalized = String(value || "").trim().toLowerCase().replace(/_/g, "-");
  if (normalized.startsWith("es")) return "es";
  if (normalized.startsWith("pt")) return "pt";
  return "en";
}

function getInviteCopy(preferredLanguageCode) {
  const languageCode = normalizePreferredLanguageCode(preferredLanguageCode);
  if (languageCode === "es") {
    return {
      heroTitle: "Te invitaron a Hands",
      greeting: "Hola",
      bodyIntro:
        "te invitó a Hands como",
      bodyDetails:
        "Haz clic abajo para aceptar tu invitación, crear tu contraseña y empezar a usar Hands. Tu rol y acceso a la organización se aplicarán automáticamente.",
      acceptInvite: "Aceptar invitación",
      linkFallback:
        "Si el botón no funciona, pega este enlace en tu navegador:",
      contactAdmin:
        "Si tienes preguntas, comunícate con tu administrador en",
      signoff: "El equipo de Hands",
      footer:
        "Este correo fue enviado como una invitación a Hands. Si no lo esperabas, puedes ignorarlo con seguridad.",
      textAcceptIntro:
        "Acepta tu invitación y crea tu contraseña aquí:",
      subject: "Te invitaron a Hands, {firstName}",
    };
  }
  if (languageCode === "pt") {
    return {
      heroTitle: "Você foi convidado para o Hands",
      greeting: "Olá",
      bodyIntro:
        "convidou você para o Hands como",
      bodyDetails:
        "Clique abaixo para aceitar o convite, criar sua senha e começar a usar o Hands. Sua função e acesso à organização serão aplicados automaticamente.",
      acceptInvite: "Aceitar convite",
      linkFallback:
        "Se o botão não funcionar, cole este link no seu navegador:",
      contactAdmin:
        "Se tiver dúvidas, entre em contato com seu administrador em",
      signoff: "Equipe Hands",
      footer:
        "Este e-mail foi enviado como um convite para o Hands. Se você não o esperava, pode ignorá-lo com segurança.",
      textAcceptIntro:
        "Aceite seu convite e crie sua senha aqui:",
      subject: "Você foi convidado para o Hands, {firstName}",
    };
  }

  return {
    heroTitle: "You're Invited to Hands",
    greeting: "Hello",
    bodyIntro: "invited you to Hands as a",
    bodyDetails:
      "Click below to accept your invite, create your password, and start using Hands. Your role and organization access will be applied automatically.",
    acceptInvite: "Accept Invite",
    linkFallback:
      "If the button does not work, paste this link into your browser:",
    contactAdmin:
      "If you have questions, contact your administrator at",
    signoff: "The Hands App Team",
    footer:
      "This email was sent as an invitation to Hands. If you did not expect it, you can safely ignore it.",
    textAcceptIntro:
      "Accept your invite and create your password here:",
    subject: "You're invited to Hands, {firstName}",
  };
}

function inviteExpiryTimestamp() {
  return admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000),
  );
}

function timestampToDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  return null;
}

function isInviteExpired(data) {
  const expiresAt = timestampToDate(data?.expiresAt);
  return expiresAt != null && expiresAt.getTime() <= Date.now();
}

function isActiveInvite(data) {
  const status = data?.status || "pending";
  return ACTIVE_INVITE_STATUSES.includes(status) && !isInviteExpired(data);
}

async function logInviteEvent({
  organizationId,
  inviteId = null,
  eventType,
  actorUserId = null,
  email = null,
  metadata = {},
}) {
  if (!organizationId || !eventType) {
    return;
  }

  try {
    await db.collection("organizations")
        .doc(organizationId)
        .collection("invite_events")
        .add({
          organizationId,
          inviteId,
          eventType,
          actorUserId,
          email,
          metadata,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
  } catch (error) {
    logger.error("Failed to log invite event:", error);
  }
}

function buildInviteEmailHtml({
  firstName,
  orgName,
  inviteUrl,
  adminEmail,
  roleName,
  preferredLanguageCode,
}) {
  const copy = getInviteCopy(preferredLanguageCode);
  const safeFirstName = escapeHtml(firstName);
  const safeOrgName = escapeHtml(orgName);
  const safeInviteUrl = escapeHtml(inviteUrl);
  const safeAdminEmail = escapeHtml(adminEmail);
  const safeRoleName = escapeHtml(roleName);
  const logoUrl = "http://cdn.mcauto-images-production.sendgrid.net/136c04a1809caad9/3116b67a-957a-419b-a46b-8abe59fc0856/1024x1024.png";

  return `
<!doctype html>
<html>
  <body style="margin:0;padding:0;background-color:#000000;font-family:Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#000000;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background-color:#1A1A1A;border-radius:12px;overflow:hidden;">
            <tr>
              <td align="center" style="padding:24px 20px 16px;background-color:#141414;">
                <img src="${logoUrl}" alt="Hands App Logo" width="120" height="96" style="display:block;border:0;width:120px;height:96px;object-fit:contain;" />
                <div style="margin-top:12px;color:#FFFFFF;font-size:28px;line-height:34px;font-weight:700;">${copy.heroTitle}</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px 22px;color:#FFFFFF;font-size:15px;line-height:24px;">
                <div style="color:#F05A2C;font-size:18px;font-weight:700;margin-bottom:10px;">${copy.greeting} ${safeFirstName},</div>
                <div style="color:#FFFFFF;margin-bottom:14px;">
                  <strong>${safeOrgName}</strong> ${copy.bodyIntro} <strong>${safeRoleName}</strong>.
                </div>
                <div style="color:#D8D8D8;margin-bottom:18px;">
                  ${copy.bodyDetails}
                </div>
                <div style="text-align:center;margin:18px 0 14px;">
                  <a href="${safeInviteUrl}" target="_blank" rel="noopener" style="display:inline-block;background-color:#F05A2C;color:#FFFFFF;text-decoration:none;padding:14px 24px;border-radius:10px;font-size:15px;line-height:20px;font-weight:700;">${copy.acceptInvite}</a>
                </div>
                <div style="text-align:center;color:#F05A2C;font-size:13px;line-height:20px;word-break:break-word;">
                  ${copy.linkFallback}<br />
                  <a href="${safeInviteUrl}" target="_blank" rel="noopener" style="color:#F05A2C;text-decoration:underline;word-break:break-word;">${safeInviteUrl}</a>
                </div>
                <div style="margin-top:18px;color:#FFFFFF;font-size:15px;line-height:24px;">${copy.contactAdmin} <strong>${safeAdminEmail}</strong>.</div>
                <div style="margin-top:16px;color:#FFFFFF;font-size:15px;line-height:24px;font-weight:600;">${copy.signoff}</div>
              </td>
            </tr>
            <tr>
              <td style="padding:14px 22px;border-top:1px solid #242424;color:#AFAFAF;font-size:12px;line-height:18px;text-align:center;">
                ${copy.footer}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildInviteEmailText({
  firstName,
  orgName,
  inviteUrl,
  adminEmail,
  roleName,
  preferredLanguageCode,
}) {
  const copy = getInviteCopy(preferredLanguageCode);
  return [
    `${copy.greeting} ${firstName},`,
    "",
    `${orgName} ${copy.bodyIntro} ${roleName}.`,
    "",
    copy.textAcceptIntro,
    inviteUrl,
    "",
    `${copy.contactAdmin} ${adminEmail}.`,
    "",
    copy.signoff,
  ].join("\n");
}

let sendgridApiKey;
try {
  sendgridApiKey = getSendGridApiKey();
  if (sendgridApiKey) {
    sgMail.setApiKey(sendgridApiKey);
  }
} catch (error) {
  logger.warn("Error configuring SendGrid for invites:", error.message);
}

async function getAuthorizedOrgContext(context, organizationId) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to manage invites.",
    );
  }

  const userDoc = await db.collection("users").doc(context.auth.uid).get();
  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Your account is missing organization access.",
    );
  }

  const userData = userDoc.data() || {};
  const memberships = Array.isArray(userData.orgMemberships) ?
    userData.orgMemberships.map((value) => String(value)) :
    [];
  const sameOrg = userData.organizationId === organizationId ||
    memberships.includes(organizationId);

  if (!sameOrg) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "You can only manage invites for your organization.",
    );
  }

  const numericRole = coerceRole(userData.userRole);
  const roleMap = userData.roles || {};
  const mappedRole = roleMap[organizationId];

  const orgDoc = await db.collection("organizations").doc(organizationId).get();
  const isOwner = orgDoc.exists && orgDoc.data()?.createdBy === context.auth.uid;
  const isManagerOrAdmin = numericRole >= 1 ||
    mappedRole === "manager" ||
    mappedRole === "admin" ||
    isOwner;

  if (!isManagerOrAdmin) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only managers and admins can manage invites.",
    );
  }

  return {
    requesterId: context.auth.uid,
    requesterEmail: userData.email || userData.userEmail || userData.emailAddress || "",
    organizationData: orgDoc.data() || {},
  };
}

async function sendInviteEmail({
  email,
  firstName,
  orgName,
  inviteUrl,
  adminEmail,
  roleName,
  preferredLanguageCode,
}) {
  if (!sendgridApiKey) {
    return {
      emailSent: false,
      emailError: "Email service not configured",
    };
  }

  const copy = getInviteCopy(preferredLanguageCode);

  const msg = {
    to: email,
    from: {
      email: getSendGridFromEmail(),
      name: getSendGridFromName(),
    },
    subject: copy.subject.replace("{firstName}", firstName),
    text: buildInviteEmailText({
      firstName,
      orgName,
      inviteUrl,
      adminEmail,
      roleName,
      preferredLanguageCode,
    }),
    html: buildInviteEmailHtml({
      firstName,
      orgName,
      inviteUrl,
      adminEmail,
      roleName,
      preferredLanguageCode,
    }),
    categories: ["staff_invite"],
  };

  try {
    await sgMail.send(msg);
    return {emailSent: true, emailError: null};
  } catch (error) {
    logger.error("Failed to send invite email:", error);
    return {
      emailSent: false,
      emailError: error.message || "Unknown email delivery error",
    };
  }
}

async function listOrgInvitesByEmail(organizationId, emailLower) {
  const snapshot = await db.collection("invites")
      .where("emailLower", "==", emailLower)
      .get();

  return snapshot.docs.filter((doc) => {
    const data = doc.data() || {};
    return data.organizationId === organizationId;
  });
}

async function markInviteReplaced(doc, replacementInviteId, revokedBy) {
  await doc.ref.set({
    status: "revoked",
    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    revokedBy,
    replacedByInviteId: replacementInviteId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function createInviteInternal({
  email,
  firstName,
  lastName,
  userRole,
  organizationId,
  locationIds,
  jobTypes,
  createdBy,
  adminEmail,
  orgName,
  preferredLanguageCode = "en",
  resendOfInviteId = null,
}) {
  const emailLower = normalizeEmail(email);
  const normalizedLanguageCode = normalizePreferredLanguageCode(
      preferredLanguageCode,
  );
  const inviteRef = db.collection("invites").doc();
  const inviteUrl = `${getBaseAppUrl()}/welcome?inviteId=${inviteRef.id}`;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const inviteData = {
    email: emailLower,
    emailLower,
    firstName: String(firstName || "").trim(),
    lastName: String(lastName || "").trim(),
    userRole: coerceRole(userRole),
    organizationId,
    locationIds: coerceStringArray(locationIds),
    locationId: coerceStringArray(locationIds)[0] || null,
    jobTypes: coerceStringArray(jobTypes),
    jobType: coerceStringArray(jobTypes)[0] || null,
    orgName,
    adminEmail,
    preferredLanguageCode: normalizedLanguageCode,
    createdBy,
    createdAt: now,
    updatedAt: now,
    inviteUrl,
    status: "pending",
    deliveryStatus: "pending",
    openedAt: null,
    acceptedAt: null,
    revokedAt: null,
    acceptedUserId: null,
    resentCount: resendOfInviteId ? 1 : 0,
    lastSentAt: null,
    sentAt: null,
    expiresAt: inviteExpiryTimestamp(),
    used: false,
    inviteVersion: 2,
    resendOfInviteId,
  };

  await inviteRef.set(inviteData);

  await logInviteEvent({
    organizationId,
    inviteId: inviteRef.id,
    eventType: resendOfInviteId ? "invite_resent" : "invite_created",
    actorUserId: createdBy,
    email: emailLower,
    metadata: {
      userRole: inviteData.userRole,
      locationCount: inviteData.locationIds.length,
      resendOfInviteId,
    },
  });

  const emailResult = await sendInviteEmail({
    email: emailLower,
    firstName: inviteData.firstName || "there",
    orgName,
    inviteUrl,
    adminEmail,
    roleName: roleLabel(inviteData.userRole),
    preferredLanguageCode: normalizedLanguageCode,
  });

  await inviteRef.set({
    status: emailResult.emailSent ? "sent" : "pending",
    deliveryStatus: emailResult.emailSent ? "sent" : "failed",
    sentAt: emailResult.emailSent ? admin.firestore.FieldValue.serverTimestamp() : null,
    lastSentAt: emailResult.emailSent ? admin.firestore.FieldValue.serverTimestamp() : null,
    deliveryError: emailResult.emailError,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  await logInviteEvent({
    organizationId,
    inviteId: inviteRef.id,
    eventType: emailResult.emailSent ? "invite_sent" : "invite_send_failed",
    actorUserId: createdBy,
    email: emailLower,
    metadata: {
      resendOfInviteId,
      deliveryError: emailResult.emailError,
    },
  });

  const finalSnapshot = await inviteRef.get();
  return {
    inviteId: inviteRef.id,
    inviteUrl,
    emailSent: emailResult.emailSent,
    emailError: emailResult.emailError,
    invite: finalSnapshot.data(),
  };
}

exports.createInvite = functions.https.onCall(async (data, context) => {
  const email = normalizeEmail(data?.email);
  const firstName = String(data?.firstName || "").trim();
  const lastName = String(data?.lastName || "").trim();
  const organizationId = String(data?.organizationId || "").trim();
  const userRole = coerceRole(data?.userRole);
  const jobTypes = userRole === 0 ? coerceStringArray(data?.jobTypes) : [];
  const preferredLanguageCode = normalizePreferredLanguageCode(
      data?.preferredLanguageCode,
  );

  if (!email || !firstName || !lastName || !organizationId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email, first name, last name, and organization ID are required.",
    );
  }

  const authz = await getAuthorizedOrgContext(context, organizationId);

  let locationIds = coerceStringArray(data?.locationIds || data?.locationId);
  if (userRole >= 1) {
    const locationSnapshot = await db.collection("organizations")
        .doc(organizationId)
        .collection("locations")
        .get();
    locationIds = locationSnapshot.docs.map((doc) => doc.id);
  }

  const existingUserSnapshot = await db.collection("users")
      .where("organizationId", "==", organizationId)
      .where("email", "==", email)
      .limit(1)
      .get();

  if (!existingUserSnapshot.empty) {
    throw new functions.https.HttpsError(
        "already-exists",
        "A team member with this email already exists in your organization.",
    );
  }

  const existingInvites = await listOrgInvitesByEmail(organizationId, email);
  const activeInvites = existingInvites.filter((doc) => isActiveInvite(doc.data()));
  const replacementInviteId = db.collection("invites").doc().id;

  for (const inviteDoc of activeInvites) {
    await markInviteReplaced(inviteDoc, replacementInviteId, authz.requesterId);
  }

  const inviteUrl = `${getBaseAppUrl()}/welcome?inviteId=${replacementInviteId}`;
  const inviteRef = db.collection("invites").doc(replacementInviteId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const orgName = data?.orgName ||
    authz.organizationData.name ||
    authz.organizationData.organizationName ||
    "Hands";

  const inviteData = {
    email,
    emailLower: email,
    firstName,
    lastName,
    userRole,
    organizationId,
    locationIds,
    locationId: locationIds[0] || null,
    jobTypes,
    jobType: jobTypes[0] || null,
    orgName,
    adminEmail: authz.requesterEmail,
    preferredLanguageCode,
    createdBy: authz.requesterId,
    createdAt: now,
    updatedAt: now,
    inviteUrl,
    status: "pending",
    deliveryStatus: "pending",
    openedAt: null,
    acceptedAt: null,
    revokedAt: null,
    acceptedUserId: null,
    resentCount: 0,
    lastSentAt: null,
    sentAt: null,
    expiresAt: inviteExpiryTimestamp(),
    used: false,
    inviteVersion: 2,
    resendOfInviteId: null,
  };

  await inviteRef.set(inviteData);

  const emailResult = await sendInviteEmail({
    email,
    firstName,
    orgName,
    inviteUrl,
    adminEmail: authz.requesterEmail,
    roleName: roleLabel(userRole),
    preferredLanguageCode,
  });

  await inviteRef.set({
    status: emailResult.emailSent ? "sent" : "pending",
    deliveryStatus: emailResult.emailSent ? "sent" : "failed",
    sentAt: emailResult.emailSent ? admin.firestore.FieldValue.serverTimestamp() : null,
    lastSentAt: emailResult.emailSent ? admin.firestore.FieldValue.serverTimestamp() : null,
    deliveryError: emailResult.emailError,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {
    success: true,
    inviteId: replacementInviteId,
    inviteUrl,
    emailSent: emailResult.emailSent,
    emailError: emailResult.emailError,
  };
});

exports.verifyInvite = functions.https.onCall(async (data) => {
  const inviteId = String(data?.inviteId || "").trim();
  if (!inviteId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing invite ID.",
    );
  }

  const inviteDoc = await db.collection("invites").doc(inviteId).get();
  if (!inviteDoc.exists) {
    return {valid: false, status: "invalid"};
  }

  const invite = inviteDoc.data() || {};
  if (isInviteExpired(invite)) {
    await inviteDoc.ref.set({
      status: "expired",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return {valid: false, status: "expired"};
  }

  if (invite.status === "revoked") {
    return {valid: false, status: "revoked"};
  }

  if (invite.status === "accepted" || invite.used === true) {
    return {
      valid: false,
      status: "accepted",
      invite: {
        email: invite.email,
        orgName: invite.orgName,
      },
    };
  }

  const shouldMarkOpened = !invite.openedAt;
  if (shouldMarkOpened) {
    await inviteDoc.ref.set({
      status: "opened",
      openedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  } else if (invite.status !== "opened") {
    await inviteDoc.ref.set({
      status: "opened",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  if (shouldMarkOpened) {
    await logInviteEvent({
      organizationId: invite.organizationId,
      inviteId,
      eventType: "invite_opened",
      email: invite.email || null,
      metadata: {
        previousStatus: invite.status || "pending",
      },
    });
  }

  return {
    valid: true,
    status: "opened",
    invite: {
      inviteId,
      email: invite.email,
      firstName: invite.firstName || "",
      lastName: invite.lastName || "",
      organizationId: invite.organizationId || "",
      orgName: invite.orgName || "Hands",
      userRole: coerceRole(invite.userRole),
      jobTypes: coerceStringArray(invite.jobTypes || invite.jobType),
      locationIds: coerceStringArray(invite.locationIds || invite.locationId),
      preferredLanguageCode: normalizePreferredLanguageCode(
          invite.preferredLanguageCode,
      ),
      expiresAt: timestampToDate(invite.expiresAt)?.toISOString() || null,
    },
  };
});

exports.lookupInviteByEmail = functions.https.onCall(async (data) => {
  const email = normalizeEmail(data?.email);
  if (!email) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing email.",
    );
  }

  const snapshot = await db.collection("invites")
      .where("emailLower", "==", email)
      .get();

  const activeInvites = snapshot.docs
      .map((doc) => ({id: doc.id, data: doc.data() || {}}))
      .filter((invite) => isActiveInvite(invite.data))
      .sort((a, b) => {
        const aTime = timestampToDate(a.data.lastSentAt) ||
          timestampToDate(a.data.createdAt) ||
          new Date(0);
        const bTime = timestampToDate(b.data.lastSentAt) ||
          timestampToDate(b.data.createdAt) ||
          new Date(0);
        return bTime.getTime() - aTime.getTime();
      });

  if (activeInvites.length === 0) {
    return {hasActiveInvite: false};
  }

  const latest = activeInvites[0];
  if (data?.logMatchEvent === true) {
    await logInviteEvent({
      organizationId: latest.data.organizationId,
      inviteId: latest.id,
      eventType: "signup_blocked_existing_invite",
      email,
      metadata: {
        source: data?.source || "unknown",
        inviteStatus: latest.data.status || "pending",
      },
    });
  }
  return {
    hasActiveInvite: true,
    inviteId: latest.id,
    inviteUrl: latest.data.inviteUrl || `${getBaseAppUrl()}/welcome?inviteId=${latest.id}`,
    orgName: latest.data.orgName || "Hands",
    status: latest.data.status || "pending",
  };
});

exports.acceptInvite = functions.https.onCall(async (data) => {
  const inviteId = String(data?.inviteId || "").trim();
  const password = String(data?.password || "");

  if (!inviteId || password.length < 6) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid invite ID and password are required.",
    );
  }

  const inviteDoc = await db.collection("invites").doc(inviteId).get();
  if (!inviteDoc.exists) {
    throw new functions.https.HttpsError(
        "not-found",
        "This invite could not be found.",
    );
  }

  const invite = inviteDoc.data() || {};
  if (isInviteExpired(invite)) {
    await inviteDoc.ref.set({
      status: "expired",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    throw new functions.https.HttpsError(
        "failed-precondition",
        "This invite has expired.",
    );
  }

  if (invite.status === "revoked") {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "This invite has been revoked.",
    );
  }

  if (invite.status === "accepted" || invite.used === true) {
    throw new functions.https.HttpsError(
        "already-exists",
        "This invite has already been accepted.",
    );
  }

  const email = normalizeEmail(invite.email);
  const organizationId = String(invite.organizationId || "").trim();
  const firstName = String(invite.firstName || "").trim();
  const lastName = String(invite.lastName || "").trim();
  const userRole = coerceRole(invite.userRole);
  const preferredLanguageCode = normalizePreferredLanguageCode(
      data?.preferredLanguageCode || invite.preferredLanguageCode,
  );

  if (!email || !organizationId) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "This invite is missing required account details.",
    );
  }

  try {
    await admin.auth().getUserByEmail(email);
    throw new functions.https.HttpsError(
        "already-exists",
        "An account with this email already exists. Sign in instead or ask an admin to resend your invite.",
    );
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    if (error?.code !== "auth/user-not-found") {
      throw new functions.https.HttpsError(
          "internal",
          `Unable to verify existing account state: ${error.message}`,
      );
    }
  }

  let locationIds = coerceStringArray(invite.locationIds || invite.locationId);
  if (userRole >= 1) {
    const locationSnapshot = await db.collection("organizations")
        .doc(organizationId)
        .collection("locations")
        .get();
    locationIds = locationSnapshot.docs.map((doc) => doc.id);
  }

  const displayName = `${firstName} ${lastName}`.trim();
  let userRecord = null;

  try {
    userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: displayName || email,
    });

    const userDoc = {
      email,
      userEmail: email,
      emailAddress: email,
      firstName,
      lastName,
      displayName: displayName || email,
      organizationId,
      orgMemberships: [organizationId],
      roles: {
        [organizationId]: roleKey(userRole),
      },
      userRole,
      jobTypes: coerceStringArray(invite.jobTypes || invite.jobType),
      jobType: coerceStringArray(invite.jobTypes || invite.jobType)[0] || null,
      locationId: locationIds[0] || null,
      locationIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: invite.createdBy || null,
      invitedBy: invite.createdBy || null,
      invitedAt: invite.createdAt || null,
      userId: userRecord.uid,
      uid: userRecord.uid,
      isActive: true,
      setupCompleted: true,
      onboardingComplete: true,
      preferredLanguageCode,
      isAdmin: userRole === 2,
      permissions: userRole === 2 ? {
        canManageUsers: true,
        canManageLocations: true,
        canManageShifts: true,
        canViewReports: true,
        canManageSettings: true,
      } : null,
      notificationSettings: {
        pushNotificationsEnabled: true,
        emailNotificationsEnabled: false,
        reminderHoursBefore: 1,
      },
    };

    await db.collection("users").doc(userRecord.uid).set(userDoc);

    await inviteDoc.ref.set({
      status: "accepted",
      used: true,
      preferredLanguageCode,
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedUserId: userRecord.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    await logInviteEvent({
      organizationId,
      inviteId,
      eventType: "invite_accepted",
      actorUserId: userRecord.uid,
      email,
      metadata: {
        userRole,
        locationCount: locationIds.length,
      },
    });

    return {
      success: true,
      uid: userRecord.uid,
      email,
      organizationId,
    };
  } catch (error) {
    if (userRecord?.uid) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
      } catch (cleanupError) {
        logger.error("Failed to cleanup partially created auth user:", cleanupError);
      }
    }

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    if (error?.errorInfo?.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError(
          "already-exists",
          "An account with this email already exists.",
      );
    }

    throw new functions.https.HttpsError(
        "internal",
        `An error occurred while accepting the invite: ${error.message}`,
    );
  }
});

exports.revokeInvite = functions.https.onCall(async (data, context) => {
  const inviteId = String(data?.inviteId || "").trim();
  if (!inviteId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing invite ID.",
    );
  }

  const inviteDoc = await db.collection("invites").doc(inviteId).get();
  if (!inviteDoc.exists) {
    throw new functions.https.HttpsError(
        "not-found",
        "Invite not found.",
    );
  }

  const invite = inviteDoc.data() || {};
  await getAuthorizedOrgContext(context, invite.organizationId);

  if (invite.status === "accepted") {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Accepted invites cannot be revoked.",
    );
  }

  await inviteDoc.ref.set({
    status: "revoked",
    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    revokedBy: context.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  await logInviteEvent({
    organizationId: invite.organizationId,
    inviteId,
    eventType: "invite_revoked",
    actorUserId: context.auth.uid,
    email: invite.email || null,
  });

  return {success: true};
});

exports.resendInvite = functions.https.onCall(async (data, context) => {
  const inviteId = String(data?.inviteId || "").trim();
  if (!inviteId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing invite ID.",
    );
  }

  const inviteDoc = await db.collection("invites").doc(inviteId).get();
  if (!inviteDoc.exists) {
    throw new functions.https.HttpsError(
        "not-found",
        "Invite not found.",
    );
  }

  const invite = inviteDoc.data() || {};
  const authz = await getAuthorizedOrgContext(context, invite.organizationId);

  if (invite.status === "accepted") {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Accepted invites cannot be resent.",
    );
  }

  await inviteDoc.ref.set({
    status: "revoked",
    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    revokedBy: context.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  const result = await createInviteInternal({
    email: invite.email,
    firstName: invite.firstName,
    lastName: invite.lastName,
    userRole: invite.userRole,
    organizationId: invite.organizationId,
    locationIds: invite.locationIds || invite.locationId,
    jobTypes: invite.jobTypes || invite.jobType,
    createdBy: authz.requesterId,
    adminEmail: authz.requesterEmail,
    orgName: invite.orgName ||
      authz.organizationData.name ||
      authz.organizationData.organizationName ||
      "Hands",
    preferredLanguageCode: invite.preferredLanguageCode,
    resendOfInviteId: inviteId,
  });

  return {
    success: true,
    inviteId: result.inviteId,
    inviteUrl: result.inviteUrl,
    emailSent: result.emailSent,
    emailError: result.emailError,
  };
});
