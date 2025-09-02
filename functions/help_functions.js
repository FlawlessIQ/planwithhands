const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const admin = require("firebase-admin");

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Send help request email to support team
 */
exports.sendHelpRequest = onCall({
  cors: true,
}, async (request) => {
  const {email, subject, message} = request.data;

  // Validate input
  if (!email || !subject || !message) {
    throw new HttpsError("invalid-argument", "Missing required fields: email, subject, or message");
  }

  // Validate email format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    throw new HttpsError("invalid-argument", "Invalid email format");
  }

  // Validate message length
  if (message.trim().length < 10) {
    throw new HttpsError("invalid-argument", "Message must be at least 10 characters long");
  }

  try {
    const db = getFirestore();

    // Get user info if authenticated
    let userInfo = {
      userId: "anonymous",
      userEmail: email,
      userRole: "unknown",
      organizationId: "unknown",
    };

    if (request.auth?.uid) {
      try {
        const userDoc = await db.collection("users").doc(request.auth.uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          userInfo = {
            userId: request.auth.uid,
            userEmail: userData.emailAddress || userData.email || email,
            userRole: userData.userRole || 0,
            organizationId: userData.organizationId || "unknown",
          };
        }
      } catch (error) {
        logger.warn("Failed to fetch user data:", error);
        // Continue with anonymous info
      }
    }

    // Store help request in Firestore
    const helpRequestData = {
      email: email.trim(),
      subject: subject.trim(),
      message: message.trim(),
      userInfo,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: "new",
      source: "app_help_form",
    };

    const helpRequestRef = await db.collection("help_requests").add(helpRequestData);
    logger.info(`Help request created: ${helpRequestRef.id}`, helpRequestData);

    // For now, we'll just store in Firestore
    // In production, you'd want to integrate with:
    // - SendGrid, Mailgun, or similar email service
    // - Support ticket system like Zendesk
    // - Slack notification to support team

    // Example integration (commented out - replace with your preferred service):
    /*
    // Send email via SendGrid or similar
    const sgMail = require('@sendgrid/mail');
    sgMail.setApiKey(process.env.SENDGRID_API_KEY);
    
    const supportEmail = {
      to: 'support@planwithhands.com',
      from: 'noreply@planwithhands.com',
      subject: `Help Request: ${subject}`,
      html: `
        <h3>New Help Request</h3>
        <p><strong>From:</strong> ${email}</p>
        <p><strong>User ID:</strong> ${userInfo.userId}</p>
        <p><strong>Organization:</strong> ${userInfo.organizationId}</p>
        <p><strong>Subject:</strong> ${subject}</p>
        <p><strong>Message:</strong></p>
        <p>${message.replace(/\n/g, '<br>')}</p>
      `,
    };
    
    await sgMail.send(supportEmail);
    */

    return {
      success: true,
      message: "Help request submitted successfully. We'll get back to you within 24 hours.",
      requestId: helpRequestRef.id,
    };
  } catch (error) {
    logger.error("Error processing help request:", error);
    throw new HttpsError("internal", "Failed to submit help request. Please try again.");
  }
});
