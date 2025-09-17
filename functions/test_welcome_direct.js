const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();

// Import the sendWelcomeEmail function from stripe_functions.js
// We'll copy the function here to test it directly
async function sendWelcomeEmail(session, orgId, subscription) {
  try {
    console.log("Sending welcome email for subscription:", subscription.id);
    
    // Get SendGrid API key from environment
    const sendgridApiKey = process.env.SENDGRID_API_KEY;
    if (!sendgridApiKey) {
      console.log("SendGrid API key not configured - skipping welcome email");
      return;
    }

    // Set SendGrid API key
    sgMail.setApiKey(sendgridApiKey);

    // Get organization details
    const orgDoc = await db.collection("organizations").doc(orgId).get();
    if (!orgDoc.exists) {
      console.log("Organization not found:", orgId);
      return;
    }

    const orgData = orgDoc.data();
    const orgName = orgData.organizationName || "Your Organization";

    // Get customer details from session/subscription
    const customerEmail = session.customer_details?.email;
    const customerName = session.customer_details?.name || "Valued Customer";

    if (!customerEmail) {
      console.log("Customer email not found for subscription:", subscription.id);
      return;
    }

    // Prepare welcome email with subscription success template
    const templateId = "d-575968e4e0c449f59ca89c1decdc8abc";
    
    const msg = {
      to: customerEmail,
      from: "noreply@em5998.planwithhands.com",
      templateId: templateId,
      dynamicTemplateData: {
        firstName: customerName.split(' ')[0] || customerName,
        orgName: orgName,
        email: customerEmail,
        temporaryPassword: "N/A", // Not applicable for subscription customers
        welcomeUrl: "https://plan-with-hands.web.app/dashboard",
        adminEmail: "support@planwithhands.com",
      },
    };

    console.log("Sending welcome email to:", customerEmail);
    console.log("Template data:", JSON.stringify(msg.dynamicTemplateData, null, 2));
    
    await sgMail.send(msg);
    console.log("Welcome email sent successfully for subscription:", subscription.id);

  } catch (error) {
    console.error("Failed to send welcome email:", error);
    if (error.response) {
      console.error("SendGrid error response:", error.response.body);
    }
  }
}

async function testWelcomeEmailFunction() {
  console.log('🚀 Testing welcome email function directly...');
  
  // Create test organization
  const testOrgId = 'test-org-' + Date.now();
  
  try {
    // Create test organization
    await db.collection('organizations').doc(testOrgId).set({
      organizationName: 'Test Restaurant Chain',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Created test organization:', testOrgId);
    
    // Test data
    const testSession = {
      customer_details: {
        email: 'conorlawless@gmail.com', // Your email for testing
        name: 'Conor Lawless'
      }
    };
    
    const testSubscription = {
      id: 'sub_test_' + Date.now(),
      customer: 'cus_test_123'
    };
    
    console.log('📧 Sending welcome email...');
    
    // Test the welcome email function
    await sendWelcomeEmail(testSession, testOrgId, testSubscription);
    
    console.log('✅ Welcome email function completed!');
    
    // Clean up
    await db.collection('organizations').doc(testOrgId).delete();
    console.log('🧹 Cleaned up test organization');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    
    // Clean up on error
    try {
      await db.collection('organizations').doc(testOrgId).delete();
    } catch (cleanupError) {
      console.error('Failed to cleanup:', cleanupError);
    }
  }
}

// Run the test
testWelcomeEmailFunction()
  .then(() => {
    console.log('Test completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Test failed:', error);
    process.exit(1);
  });
