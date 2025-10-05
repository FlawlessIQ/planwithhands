const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Initialize with specific database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

async function triggerDailySummaryManual() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    const targetEmail = 'con.lawless@gmail.com';
    
    // Date for Oct 1, 2025
    const targetDate = new Date('2025-10-01');
    
    console.log(`\n🔄 Triggering daily summary for organization: ${orgId}`);
    console.log(`📅 Date: ${targetDate.toDateString()}`);
    console.log(`📧 Email: ${targetEmail}\n`);
    
    // Call the triggerDailySummary function
    const functions = require('firebase-functions-test')();
    const triggerFunction = require('./lib/scheduledDailySummary').triggerDailySummary;
    
    // Prepare the data
    const data = {
      orgId: orgId,
      targetDate: targetDate.toISOString(),
      testEmail: targetEmail  // This will override admin emails
    };
    
    // Create a mock context with auth
    const context = {
      auth: {
        uid: 'manual-trigger',
        token: {}
      }
    };
    
    console.log('⏳ Generating and sending daily summary...\n');
    
    const result = await triggerFunction(data, context);
    
    console.log('\n✅ Daily summary triggered successfully!');
    console.log('📧 Email should arrive at:', targetEmail);
    console.log('\n📊 Result:', JSON.stringify(result, null, 2));
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error triggering daily summary:', error);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

triggerDailySummaryManual();
