const functions = require('firebase-functions-test')();
const admin = require('firebase-admin');

// Initialize the app if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Import the stripe functions
const stripeModule = require('./stripe_functions');

// Simulate a Stripe checkout.session.completed event
async function testWelcomeEmailWebhook() {
  console.log('🚀 Testing welcome email webhook...');
  
  // Create a test organization first
  const testOrgId = 'test-org-welcome-' + Date.now();
  const db = admin.firestore();
  
  try {
    // Create test organization
    await db.collection('organizations').doc(testOrgId).set({
      organizationName: 'Test Welcome Organization',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Created test organization:', testOrgId);
    
    // Simulate Stripe webhook event
    const mockReq = {
      headers: {
        'stripe-signature': 'mock-signature'
      },
      rawBody: Buffer.from('mock-webhook-body')
    };
    
    const mockRes = {
      status: (code) => ({
        send: (message) => {
          console.log(`Response: ${code} - ${message}`);
        }
      }),
      json: (data) => {
        console.log('Response JSON:', data);
      }
    };
    
    // Mock the Stripe webhook constructor to skip signature verification
    const functions = require('firebase-functions');
    const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
    stripe.webhooks.constructEvent = () => ({
      type: 'checkout.session.completed',
      data: {
        object: {
          mode: 'subscription',
          subscription: 'sub_test123',
          metadata: {
            orgId: testOrgId
          },
          customer_details: {
            email: 'test@example.com',
            name: 'Test User'
          }
        }
      }
    });
    
    // Mock Stripe subscription retrieve
    stripe.subscriptions.retrieve = () => Promise.resolve({
      id: 'sub_test123',
      status: 'trialing',
      customer: 'cus_test123',
      trial_end: Math.floor(Date.now() / 1000) + (14 * 24 * 60 * 60), // 14 days from now
      items: {
        data: [{
          price: {
            id: 'price_test123'
          }
        }]
      }
    });
    
    // Mock Stripe customer retrieve
    stripe.customers.retrieve = () => Promise.resolve({
      id: 'cus_test123',
      email: 'test@example.com',
      name: 'Test User'
    });
    
    console.log('📧 Triggering webhook handler...');
    
    // Call the webhook handler
    await stripeModule.stripeWebhook(mockReq, mockRes);
    
    console.log('✅ Webhook handler completed successfully!');
    
    // Clean up - delete test organization
    await db.collection('organizations').doc(testOrgId).delete();
    console.log('🧹 Cleaned up test organization');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    
    // Clean up on error too
    try {
      await db.collection('organizations').doc(testOrgId).delete();
    } catch (cleanupError) {
      console.error('Failed to cleanup:', cleanupError);
    }
  }
}

// Run the test
testWelcomeEmailWebhook()
  .then(() => {
    console.log('Test completed');
    functions.cleanup();
    process.exit(0);
  })
  .catch((error) => {
    console.error('Test failed:', error);
    functions.cleanup();
    process.exit(1);
  });
