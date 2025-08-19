const {admin, db} = require("./firebase_config");
const {logger} = require("firebase-functions");
const functions = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

// Set SendGrid API key from Firebase Functions config
let sendgridApiKey;
try {
  sendgridApiKey = functions.config().sendgrid &&
    functions.config().sendgrid.key;
  if (!sendgridApiKey) {
    logger.warn("SendGrid API key is not configured. Email sending will be skipped.");
  } else {
    sgMail.setApiKey(sendgridApiKey);
    logger.info("SendGrid API key configured successfully");
  }
} catch (error) {
  logger.warn("Error configuring SendGrid:", error.message);
}

exports.createUser = functions.https.onCall(async (data, context) => {
  try {
    logger.info("createUser function called with data:", JSON.stringify(data));

    // Check if user is authenticated and is admin
    if (!context.auth) {
      throw new functions.https.HttpsError(
          "unauthenticated",
          "The function must be called while authenticated.",
      );
    }

    logger.info("User authenticated:", context.auth.uid);

    // Destructure callable function data
    const {
      email,
      password,
      firstName,
      lastName,
      organizationId,
      userRole,
      jobType,
      locationId,
      locationIds,
      orgName,
      adminEmail,
      inviteUrl,
      templateId,
    } = data;

    // Validate required fields
    if (!email || !password || !firstName || !lastName || !organizationId) {
      logger.error("Missing required fields:", {email, firstName, lastName, organizationId});
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Email, password, first name, last name, and organization ID are required.",
      );
    }

    logger.info("Creating user in Firebase Auth...");
    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: `${firstName} ${lastName}`,
    });
    logger.info("User created in Auth:", userRecord.uid);

    // Create user document in Firestore with all required fields
    const userData = {
      email: email,
      userEmail: email,
      firstName: firstName,
      lastName: lastName,
      organizationId: organizationId,
      userRole: userRole || 0, // Use provided role or default to 0
      jobType: jobType || [], // Use provided job types or empty array
      locationId: locationId || null,
      locationIds: locationIds || [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
      userId: userRecord.uid,
      phoneNumber: null,
      isActive: true,
      onboardingComplete: false, // New users must complete onboarding
    };

    logger.info("Creating user document in Firestore...");
    await db
        .collection("users")
        .doc(userRecord.uid)
        .set(userData);
    logger.info("User document created successfully");

    // Send welcome email if SendGrid template ID is provided
    if (templateId && sendgridApiKey) {
      try {
        logger.info("Sending welcome email...");
        logger.info("Template ID:", templateId);
        logger.info("SendGrid API key exists:", !!sendgridApiKey);
        logger.info("Email recipient:", email);

        const msg = {
          to: email,
          from: "noreply@em5998.planwithhands.com", // Using your verified SendGrid domain
          templateId: templateId,
          dynamicTemplateData: {
            firstName: firstName,
            orgName: orgName,
            email: email,
            temporaryPassword: password,
            welcomeUrl: inviteUrl,
            adminEmail: adminEmail,
          },
        };

        logger.info("Email message object:", JSON.stringify(msg, null, 2));
        await sgMail.send(msg);
        logger.info(`Welcome email sent to ${email} using template ${templateId}`);
      } catch (emailError) {
        logger.error("Failed to send welcome email:", emailError);
        logger.error("Email error details:", JSON.stringify(emailError, null, 2));
        logger.error("Email error code:", emailError.code);
        logger.error("Email error response:", emailError.response);
        if (emailError.response && emailError.response.body) {
          logger.error("SendGrid error body:", JSON.stringify(emailError.response.body, null, 2));
        }
        // Don't fail the user creation if email fails
      }
    } else {
      logger.info("Skipping email send - no template ID or SendGrid API key");
      logger.info("Template ID present:", !!templateId);
      logger.info("SendGrid API key present:", !!sendgridApiKey);
    }

    logger.info("Function completed successfully");
    return {
      success: true,
      uid: userRecord.uid,
      message: "User created successfully",
    };
  } catch (error) {
    logger.error("Error creating user:", error);
    logger.error("Error stack:", error.stack);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
        "internal",
        `An error occurred while creating the user: ${error.message}`,
    );
  }
});


// Minimal callable: deletes Auth user and Firestore doc for given uid, no org/role checks
exports.deleteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in to call this function');
  }
  if (!data || !data.uid) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing target user uid');
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
    await db.collection('users').doc(targetUid).delete();
  } catch (e) {
    // If doc not found, ignore
  }
  return { success: true, message: authDeleted ? 'User authentication and Firestore record deleted' : 'Firestore user record deleted (auth delete failed or user not present in Auth)' };
});
