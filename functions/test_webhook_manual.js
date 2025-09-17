const functions = require("firebase-functions");
const {admin, db} = require("./firebase_config");
const stripe = require("stripe")(functions.config().stripe.secret);

// Manual webhook test function
exports.testWebhookManual = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
      console.log("Starting manual webhook test...");
      
      try {
        // Get the latest subscription
        const subscription = await stripe.subscriptions.retrieve("sub_1S8J20FzroJ5o7DAtewyRfx6");
        console.log("Retrieved subscription:", subscription.id);
        console.log("Customer:", subscription.customer);
        console.log("OrgId metadata:", subscription.metadata?.orgId);
        
        // Get customer details
        const customer = await stripe.customers.retrieve(subscription.customer);
        console.log("Customer email:", customer.email);
        console.log("Customer metadata:", customer.metadata);
        
        // Create a mock subscription.created event
        const mockEvent = {
          type: "customer.subscription.created",
          data: {
            object: subscription
          }
        };
        
        console.log("Mock event created, processing...");
        
        // Import the sendWelcomeEmail function
        const {sendWelcomeEmail} = require("./email_functions");
        
        // Call sendWelcomeEmail directly
        await sendWelcomeEmail({ customer_details: {} }, subscription.metadata?.orgId, subscription);
        
        return {
          success: true,
          message: "Manual webhook test completed",
          subscriptionId: subscription.id,
          customerEmail: customer.email,
          orgId: subscription.metadata?.orgId
        };
        
      } catch (error) {
        console.error("Manual webhook test failed:", error);
        throw new functions.https.HttpsError("internal", `Test failed: ${error.message}`);
      }
    });