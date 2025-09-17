const functions = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

// Manual send welcome email test
exports.testSendEmail = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      console.log("Manual email test starting...");
      
      try {
        // Use the existing SendGrid configuration
        sgMail.setApiKey(functions.config().sendgrid.key);
        
        const { email, orgId } = data;
        if (!email || !orgId) {
          throw new functions.https.HttpsError("invalid-argument", "email and orgId required");
        }
        
        console.log(`Sending test email to: ${email} for orgId: ${orgId}`);
        
        const msg = {
          to: email,
          from: 'support@planwithhands.com',
          subject: 'Welcome to Plan With Hands - Test Email',
          html: `
            <h1>Welcome to Plan With Hands!</h1>
            <p>Hi there,</p>
            <p>This is a test email to confirm email delivery is working.</p>
            <p>Your organization ID: ${orgId}</p>
            <p>You can access your dashboard at: <a href="https://plan-with-hands.web.app/dashboard">https://plan-with-hands.web.app/dashboard</a></p>
            <p>Best regards,<br>The Plan With Hands Team</p>
          `
        };
        
        await sgMail.send(msg);
        console.log("Test email sent successfully!");
        
        return {
          success: true,
          message: "Test email sent successfully",
          sentTo: email,
          orgId: orgId
        };
        
      } catch (error) {
        console.error("Failed to send test email:", error);
        throw new functions.https.HttpsError("internal", `Failed to send email: ${error.message}`);
      }
    });