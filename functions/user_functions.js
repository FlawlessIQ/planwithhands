const {admin, db} = require("./firebase_config");
const {logger} = require("firebase-functions");
const functions = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

// Set SendGrid API key from Firebase Functions config
const sendgridApiKey = functions.config().sendgrid &&
  functions.config().sendgrid.key;
if (!sendgridApiKey) {
  logger.error("SendGrid API key is not configured. Please set it with: " +
    "firebase functions:config:set sendgrid.key=\"YOUR_API_KEY\"");
} else {
  sgMail.setApiKey(sendgridApiKey);
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
        const msg = {
          to: email,
          from: "noreply@plan-with-hands.web.app",
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

        await sgMail.send(msg);
        logger.info(`Welcome email sent to ${email} using template ${templateId}`);
      } catch (emailError) {
        logger.error("Failed to send welcome email:", emailError);
        // Don't fail the user creation if email fails
      }
    } else {
      logger.info("Skipping email send - no template ID or SendGrid API key");
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
