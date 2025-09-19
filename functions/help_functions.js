const functions = require("firebase-functions");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const sgMail = require('@sendgrid/mail');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Initialize SendGrid with API key from environment variable
if (process.env.SENDGRID_API_KEY) {
  sgMail.setApiKey(process.env.SENDGRID_API_KEY);
} else {
  logger.warn("SENDGRID_API_KEY environment variable not set - emails will not be sent");
}

/**
 * Send help request email to support team
 */
exports.sendHelpRequest = functions.https.onRequest(async (req, res) => {
  // Robust CORS handling
  const origin = req.get('origin') || '*';
  const reqHeaders = req.get('Access-Control-Request-Headers');
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Origin', origin);
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', reqHeaders || 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const {email, subject, message} = req.body;

  // Validate input
  if (!email || !subject || !message) {
    res.status(400).json({ error: "Missing required fields: email, subject, or message" });
    return;
  }

  // Validate email format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    res.status(400).json({ error: "Invalid email format" });
    return;
  }

  // Validate message length
  if (message.trim().length < 10) {
    res.status(400).json({ error: "Message must be at least 10 characters long" });
    return;
  }

  try {
    const db = admin.firestore();

    // Get user info - simplified for HTTP function
    let userInfo = {
      userId: "anonymous",
      userEmail: email,
      userRole: "unknown",
      organizationId: "unknown",
    };

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

    // Send email via SendGrid
    if (process.env.SENDGRID_API_KEY) {
      try {
        const supportEmail = {
          to: 'conor@planwithhands.com',
          from: 'noreply@em5998.planwithhands.com',
          subject: `Help Request: ${subject}`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #FF6B35;">New Help Request</h2>
              <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <p><strong>From:</strong> ${email}</p>
                <p><strong>User ID:</strong> ${userInfo.userId}</p>
                <p><strong>Organization:</strong> ${userInfo.organizationId}</p>
                <p><strong>User Role:</strong> ${userInfo.userRole}</p>
                <p><strong>Request ID:</strong> ${helpRequestRef.id}</p>
              </div>
              <h3>Subject:</h3>
              <p>${subject}</p>
              <h3>Message:</h3>
              <div style="background: white; padding: 15px; border-left: 4px solid #FF6B35; margin: 10px 0;">
                ${message.replace(/\n/g, '<br>')}
              </div>
              <hr style="margin: 30px 0; border: none; border-top: 1px solid #ddd;">
              <p style="color: #666; font-size: 12px;">
                This email was sent from the Hands app help system.<br>
                Timestamp: ${new Date().toISOString()}
              </p>
            </div>
          `,
        };
        
        await sgMail.send(supportEmail);
        logger.info(`Email sent successfully for help request: ${helpRequestRef.id}`);
      } catch (emailError) {
        logger.error("Failed to send email notification:", emailError);
        // Don't fail the whole request if email fails - the request is still stored
      }
    }

    res.status(200).json({
      success: true,
      message: "Help request submitted successfully. We'll get back to you within 24 hours.",
      requestId: helpRequestRef.id,
    });
  } catch (error) {
    logger.error("Error processing help request:", error);
    res.status(500).json({ error: "Failed to submit help request. Please try again." });
  }
});
