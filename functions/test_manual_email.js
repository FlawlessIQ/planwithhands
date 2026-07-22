const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");

// Test function to manually trigger welcome email for recent signup
exports.testManualWelcomeEmail = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      const { email } = data;

      if (!email) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Email is required"
        );
      }

      try {
        console.log(`Testing manual welcome email for: ${email}`);

        // Find the most recent organization for this email
        const usersSnapshot = await admin.auth().listUsers();
        const user = usersSnapshot.users.find(u => u.email === email);
        
        if (!user) {
          throw new Error(`User not found with email: ${email}`);
        }

        console.log(`Found user: ${user.uid}`);

        // Find the organization for this user
        const orgSnapshot = await db.collection("organizations")
          .where("createdBy", "==", user.uid)
          .orderBy("createdAt", "desc")
          .limit(1)
          .get();

        if (orgSnapshot.empty) {
          throw new Error(`No organization found for user: ${user.uid}`);
        }

        const org = orgSnapshot.docs[0];
        const orgId = org.id;
        console.log(`Found organization: ${orgId}`);

        // Call the existing sendWelcomeEmail function
        const { sendWelcomeEmail } = require("./stripe_functions");
        
        // Create a mock subscription object
        const mockSubscription = {
          id: "test_subscription",
          customer: "test_customer",
          status: "active",
          metadata: {
            orgId: orgId,
            email: email
          }
        };

        await sendWelcomeEmail({ customer_details: {} }, orgId, mockSubscription);
        
        console.log(`Welcome email sent successfully to: ${email}`);
        return { success: true, message: `Welcome email sent to ${email}` };

      } catch (error) {
        console.error('Error sending manual welcome email:', error);
        throw new functions.https.HttpsError(
          "internal",
          `Failed to send welcome email: ${error.message}`
        );
      }
    });