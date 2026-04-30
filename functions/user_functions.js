const {admin, db} = require("./firebase_config");
const {logger} = require("firebase-functions");
const functions = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

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

function escapeHtml(value) {
  return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
}

function buildInviteEmailHtml({firstName, orgName, email, temporaryPassword, welcomeUrl, adminEmail}) {
  const safeFirstName = escapeHtml(firstName);
  const safeOrgName = escapeHtml(orgName);
  const safeEmail = escapeHtml(email);
  const safePassword = escapeHtml(temporaryPassword);
  const safeWelcomeUrl = escapeHtml(welcomeUrl);
  const safeAdminEmail = escapeHtml(adminEmail);
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
                <div style="margin-top:12px;color:#FFFFFF;font-size:28px;line-height:34px;font-weight:700;">Welcome to Hands App</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px 22px;color:#FFFFFF;font-size:15px;line-height:24px;">
                <div style="color:#F05A2C;font-size:18px;font-weight:700;margin-bottom:10px;">Hello ${safeFirstName},</div>
                <div style="color:#FFFFFF;margin-bottom:14px;">
                  <strong>${safeOrgName}</strong> has invited you to Hands App so you can complete daily checklists and stay in sync with your team.
                </div>

                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;background-color:#111111;border:1px solid #4A2417;border-radius:10px;">
                  <tr>
                    <td style="padding:18px;text-align:center;">
                      <div style="color:#F05A2C;font-size:20px;line-height:26px;font-weight:700;margin-bottom:10px;">Your Login Details</div>
                      <div style="color:#FFFFFF;font-size:16px;line-height:24px;margin-bottom:6px;"><strong>Email:</strong> ${safeEmail}</div>
                      <div style="color:#CFCFCF;font-size:13px;line-height:18px;font-weight:700;margin-top:12px;">Temporary Password</div>
                      <div style="margin-top:10px;display:inline-block;background-color:#0B0B0B;color:#FFFFFF;padding:12px 16px;border-radius:8px;border:1px solid #2A2A2A;font-family:Courier,monospace;font-size:30px;line-height:30px;letter-spacing:4px;">${safePassword}</div>
                      <div style="color:#BEBEBE;font-size:14px;line-height:22px;font-style:italic;margin-top:14px;">You can change this password after your first login.</div>
                    </td>
                  </tr>
                </table>

                <div style="color:#F05A2C;font-size:16px;line-height:22px;font-weight:700;margin:18px 0 8px;">What to Expect</div>
                <ul style="padding-left:20px;margin:0 0 18px;color:#D8D8D8;">
                  <li style="margin-bottom:8px;"><span style="color:#FFFFFF;font-weight:700;">Step-by-Step Checklists</span> with guided daily tasks.</li>
                  <li style="margin-bottom:8px;"><span style="color:#FFFFFF;font-weight:700;">Photo Verification</span> for proof of completion.</li>
                  <li style="margin-bottom:8px;"><span style="color:#FFFFFF;font-weight:700;">Mobile and Web Access</span> from phone or desktop.</li>
                  <li style="margin-bottom:8px;"><span style="color:#FFFFFF;font-weight:700;">Team Communications</span> for updates from managers.</li>
                  <li style="margin-bottom:8px;"><span style="color:#FFFFFF;font-weight:700;">Training Materials</span> available anytime.</li>
                </ul>

                <div style="color:#FFFFFF;margin-bottom:14px;">Ready to get started? Use the button below to complete your account setup:</div>

                <div style="text-align:center;margin:18px 0 14px;">
                  <a href="${safeWelcomeUrl}" target="_blank" rel="noopener" style="display:inline-block;background-color:#F05A2C;color:#FFFFFF;text-decoration:none;padding:14px 24px;border-radius:10px;font-size:15px;line-height:20px;font-weight:700;">Complete Account Setup</a>
                </div>

                <div style="text-align:center;color:#F05A2C;font-size:13px;line-height:20px;word-break:break-word;">
                  If the button does not work, paste this link into your browser:<br />
                  <a href="${safeWelcomeUrl}" target="_blank" rel="noopener" style="color:#F05A2C;text-decoration:underline;word-break:break-word;">${safeWelcomeUrl}</a>
                </div>

                <div style="margin-top:18px;color:#FFFFFF;font-size:15px;line-height:24px;">If you have questions, contact your administrator at <strong>${safeAdminEmail}</strong>.</div>
                <div style="margin-top:16px;color:#FFFFFF;font-size:15px;line-height:24px;font-weight:600;">The Hands App Team</div>
              </td>
            </tr>
            <tr>
              <td style="padding:14px 22px;border-top:1px solid #242424;color:#AFAFAF;font-size:12px;line-height:18px;text-align:center;">
                This email was sent to ${safeEmail}. If you did not expect it, you can safely ignore it.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildInviteEmailText({firstName, orgName, email, temporaryPassword, welcomeUrl, adminEmail}) {
  return [
    `Hello ${firstName},`,
    "",
    `${orgName} has invited you to Hands App.`,
    "",
    "Your Login Details",
    `Email: ${email}`,
    `Temporary Password: ${temporaryPassword}`,
    "",
    "Complete your account setup here:",
    welcomeUrl,
    "",
    `If you have questions, contact your administrator at ${adminEmail}.`,
    "",
    "The Hands App Team",
  ].join("\n");
}

// Set SendGrid API key from env or Firebase runtime config
let sendgridApiKey;
try {
  sendgridApiKey = getSendGridApiKey();
  if (!sendgridApiKey) {
    logger.warn("SendGrid API key is not configured. Email sending will be skipped.");
  } else {
    sgMail.setApiKey(sendgridApiKey);
    logger.info("SendGrid API key configured successfully");
    logger.info(`SendGrid sender configured as ${getSendGridFromEmail()}`);
  }
} catch (error) {
  logger.warn("Error configuring SendGrid:", error.message);
}

exports.createUser = functions.https.onCall(async (data, context) => {
  logger.warn("Deprecated createUser callable invoked", {
    caller: context.auth?.uid || null,
    organizationId: data?.organizationId || null,
    email: data?.email || null,
  });

  throw new functions.https.HttpsError(
      "failed-precondition",
      "Direct pre-creation of staff accounts is disabled. Use createInvite and acceptInvite instead.",
  );
});

function normalizeSignupEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function normalizeSignupLanguage(value) {
  const normalized = String(value || "").trim().toLowerCase().replace(/_/g, "-");
  if (normalized.startsWith("es")) return "es";
  if (normalized.startsWith("pt")) return "pt";
  return "en";
}

function asPositiveInt(value, fallback = 0) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

async function hasActiveInviteForEmail(email) {
  const activeStatuses = ["pending", "sent", "opened"];
  const inviteSnap = await db.collection("invites")
      .where("emailLower", "==", email)
      .get();
  return inviteSnap.docs.some((doc) => {
    const invite = doc.data() || {};
    const status = String(invite.status || "pending").toLowerCase();
    if (!activeStatuses.includes(status)) return false;
    if (invite.used === true) return false;
    if (invite.expiresAt?.toDate && invite.expiresAt.toDate() < new Date()) {
      return false;
    }
    return true;
  });
}

exports.createOrganizationSignup = functions.region("us-central1").https.onCall(async (data) => {
  const email = normalizeSignupEmail(data?.email);
  const password = String(data?.password || "");
  const firstName = String(data?.firstName || "").trim();
  const lastName = String(data?.lastName || "").trim();
  const organizationName = String(data?.organizationName || "").trim();
  const businessType = String(data?.businessType || "").trim() || null;
  const numberOfEmployees = asPositiveInt(data?.numberOfEmployees, 0);
  const intendedLocationQuantity = asPositiveInt(data?.numberOfLocations, 1);
  const preferredLanguageCode = normalizeSignupLanguage(
      data?.preferredLanguageCode,
  );
  const acceptedTerms = data?.acceptedTerms === true;

  if (!email || !firstName || !lastName || !organizationName) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Business name, owner name, and email are required.",
    );
  }

  if (password.length < 8) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Password must be at least 8 characters.",
    );
  }

  if (!acceptedTerms) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Terms must be accepted before creating an account.",
    );
  }

  if (await hasActiveInviteForEmail(email)) {
    throw new functions.https.HttpsError(
        "already-exists",
        "This email already has an active invite. Finish that invite instead.",
    );
  }

  try {
    await admin.auth().getUserByEmail(email);
    throw new functions.https.HttpsError(
        "already-exists",
        "An account with this email already exists. Sign in instead.",
    );
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    if (error?.code !== "auth/user-not-found") {
      throw new functions.https.HttpsError(
          "internal",
          `Unable to verify account state: ${error.message}`,
      );
    }
  }

  const displayName = `${firstName} ${lastName}`.trim();
  const orgRef = db.collection("organizations").doc();
  let userRecord = null;

  try {
    userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: displayName || email,
    });

    const now = admin.firestore.FieldValue.serverTimestamp();
    const trialEndsAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
    );
    const salesAssisted = intendedLocationQuantity >= 5;

    const batch = db.batch();
    batch.set(orgRef, {
      name: organizationName,
      organizationName,
      businessType,
      numberOfEmployees,
      intendedLocationQuantity,
      createdAt: now,
      updatedAt: now,
      createdBy: userRecord.uid,
      ownerEmail: email,
      isActive: true,
      subscriptionStatus: "trial",
      trialEndsAt,
      salesAssisted,
      onboardingStatus: {
        firstLocation: false,
        teamInvited: false,
        shiftCreated: false,
        workflowCreated: false,
        billingAdded: false,
      },
      settings: {
        allowUserRegistration: true,
        requireLocationSelection: true,
        defaultShiftLength: 8,
        defaultLanguageCode: preferredLanguageCode,
      },
    });

    batch.set(db.collection("users").doc(userRecord.uid), {
      firstName,
      lastName,
      displayName: displayName || email,
      email,
      userEmail: email,
      emailAddress: email,
      userId: userRecord.uid,
      uid: userRecord.uid,
      userRole: 2,
      organizationId: orgRef.id,
      orgMemberships: [orgRef.id],
      roles: {
        [orgRef.id]: "admin",
      },
      locationIds: [],
      locationId: null,
      jobTypes: [],
      jobType: null,
      isAdmin: true,
      isActive: true,
      setupCompleted: false,
      onboardingComplete: false,
      preferredLanguageCode,
      preferredLanguageSource: "signup",
      preferredLocaleResolved: preferredLanguageCode,
      createdAt: now,
      updatedAt: now,
      permissions: {
        canManageUsers: true,
        canManageLocations: true,
        canManageShifts: true,
        canViewReports: true,
        canManageSettings: true,
      },
      notificationSettings: {
        pushNotificationsEnabled: true,
        emailNotificationsEnabled: false,
        reminderHoursBefore: 1,
      },
    });

    await batch.commit();

    return {
      success: true,
      uid: userRecord.uid,
      email,
      organizationId: orgRef.id,
      userRole: 2,
      preferredLanguageCode,
      salesAssisted,
    };
  } catch (error) {
    if (userRecord?.uid) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
      } catch (cleanupError) {
        logger.error("Failed to cleanup partial signup auth user:", cleanupError);
      }
    }

    if (error instanceof functions.https.HttpsError) throw error;
    if (error?.errorInfo?.code === "auth/email-already-exists") {
      throw new functions.https.HttpsError(
          "already-exists",
          "An account with this email already exists.",
      );
    }
    throw new functions.https.HttpsError(
        "internal",
        `Unable to create organization account: ${error.message}`,
    );
  }
});


// Send organization signup notification email to admin
exports.sendOrganizationSignupNotification = functions.https.onCall(async (data, context) => {
  try {
    logger.info("sendOrganizationSignupNotification function called with data:", JSON.stringify(data));

    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated.",
      );
    }

    // Destructure callable function data
    const {
      organizationName,
      adminFirstName,
      adminLastName,
      adminEmail,
      businessType,
      numberOfEmployees,
      numberOfLocations,
      subscriptionType,
      organizationId,
      createdAt,
    } = data;

    // Validate required fields
    if (!organizationName || !adminFirstName || !adminLastName || !adminEmail || !organizationId) {
      logger.error("Missing required fields for organization signup notification");
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Organization name, admin name, email, and organization ID are required.",
      );
    }

    // Send admin notification email if SendGrid is configured
    if (sendgridApiKey) {
      try {
        logger.info("Sending organization signup notification email...");
        
        const templateId = "d-93870b1c6d6943419a15117c553858da"; // Your provided template ID
        
        const msg = {
          to: "admin@planwithhands.com", // Admin email to receive notifications
          from: {
            email: getSendGridFromEmail(),
            name: getSendGridFromName(),
          },
          templateId: templateId,
          dynamicTemplateData: {
            // Variables that match the SendGrid template
            orgName: organizationName,
            adminEmail: adminEmail,
            createdDate: createdAt ? new Date(createdAt).toLocaleDateString('en-US', {
              year: 'numeric',
              month: 'long',
              day: 'numeric'
            }) : new Date().toLocaleDateString('en-US', {
              year: 'numeric',
              month: 'long',
              day: 'numeric'
            }),
            planType: `${subscriptionType || 'Trial'} Plan`,
            
            // Additional variables for URLs
            webPortalUrl: "https://app.planwithhands.com",
            stripeUrl: "https://dashboard.stripe.com",
            helpUrl: "https://docs.planwithhands.com",
            
            // Keep original variables for backward compatibility
            organizationName: organizationName,
            adminFirstName: adminFirstName,
            adminLastName: adminLastName,
            businessType: businessType || "Not specified",
            numberOfEmployees: numberOfEmployees || "Not specified",
            numberOfLocations: numberOfLocations || "Not specified",
            subscriptionType: subscriptionType || "Trial",
            organizationId: organizationId,
            signupDate: createdAt ? new Date(createdAt).toLocaleDateString() : new Date().toLocaleDateString(),
            adminFullName: `${adminFirstName} ${adminLastName}`,
            firestoreUrl: `https://console.firebase.google.com/project/hands-d31f9/firestore/data/organizations/${organizationId}`,
          },
        };

        logger.info("Organization signup notification email message:", JSON.stringify(msg, null, 2));
        await sgMail.send(msg);
        logger.info(`Organization signup notification sent to admin for organization: ${organizationName}`);
        
        return {
          success: true,
          message: "Organization signup notification sent successfully",
        };
      } catch (emailError) {
        logger.error("Failed to send organization signup notification:", emailError);
        logger.error("Email error details:", JSON.stringify(emailError, null, 2));
        
        throw new functions.https.HttpsError(
            "internal",
            `Failed to send organization signup notification: ${emailError.message}`,
        );
      }
    } else {
      logger.warn("SendGrid API key not configured - skipping organization signup notification");
      throw new functions.https.HttpsError(
          "failed-precondition",
          "Email service not configured",
      );
    }
  } catch (error) {
    logger.error("Error in sendOrganizationSignupNotification:", error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
        "internal",
        `An error occurred while sending organization signup notification: ${error.message}`,
    );
  }
});

// Minimal callable: deletes Auth user and Firestore doc for given uid, no org/role checks
exports.deleteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in to call this function");
  }
  if (!data || !data.uid) {
    throw new functions.https.HttpsError("invalid-argument", "Missing target user uid");
  }
  const targetUid = data.uid;
  let authDeleted = false;
  try {
    await admin.auth().deleteUser(targetUid);
    authDeleted = true;
  } catch (e) {
    // If user not in Auth, ignore
  }
  try {
    await db.collection("users").doc(targetUid).delete();
  } catch (e) {
    // If doc not found, ignore
  }
  return {success: true, message: authDeleted ? "User authentication and Firestore record deleted" : "Firestore user record deleted (auth delete failed or user not present in Auth)"};
});
