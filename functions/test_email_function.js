const functions = require("firebase-functions");
const sgMail = require("@sendgrid/mail");

// Set SendGrid API key
sgMail.setApiKey(functions.config().sendgrid.api_key);

// Function to test welcome email directly
exports.testWelcomeEmail = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const { orgId, email } = data;

      if (!orgId || !email) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required parameters: orgId, email"
        );
      }

      try {
        console.log(`Testing welcome email for orgId: ${orgId}, email: ${email}`);

        const msg = {
          to: email,
          from: {
            email: 'hello@handsapp.ai',
            name: 'Hands App Team'
          },
          subject: 'Welcome to Hands App! Your account is ready.',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9;">
              <div style="background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                <div style="text-align: center; margin-bottom: 30px;">
                  <h1 style="color: #F05A2C; margin-bottom: 10px;">Welcome to Hands App!</h1>
                  <p style="color: #666; font-size: 16px;">Your account is now ready to use.</p>
                </div>
                
                <div style="margin-bottom: 30px;">
                  <h2 style="color: #333; font-size: 20px;">🎉 You're all set!</h2>
                  <p style="color: #666; line-height: 1.6;">
                    Your Hands App subscription is now active and your team can start using the platform right away.
                  </p>
                </div>

                <div style="margin-bottom: 30px;">
                  <h3 style="color: #333; font-size: 18px;">Next steps:</h3>
                  <ul style="color: #666; line-height: 1.8; padding-left: 20px;">
                    <li>Set up your team members and locations</li>
                    <li>Create your first checklist templates</li>
                    <li>Start tracking daily operations</li>
                  </ul>
                </div>

                <div style="text-align: center; margin-top: 30px;">
                  <a href="https://app.handsapp.ai" style="background-color: #F05A2C; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                    Access Your Dashboard
                  </a>
                </div>

                <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center;">
                  <p style="color: #999; font-size: 14px;">
                    Need help? Reply to this email or visit our <a href="https://handsapp.ai/support" style="color: #F05A2C;">support center</a>.
                  </p>
                </div>
              </div>
            </div>
          `
        };

        console.log('Sending welcome email with SendGrid...');
        await sgMail.send(msg);
        console.log('Welcome email sent successfully!');

        return { success: true, message: 'Welcome email sent successfully' };

      } catch (error) {
        console.error('Error sending welcome email:', error);
        if (error.response) {
          console.error('SendGrid response:', error.response.body);
        }
        throw new functions.https.HttpsError(
          "internal",
          `Failed to send welcome email: ${error.message}`
        );
      }
    });