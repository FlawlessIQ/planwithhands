// Simple script to trigger daily summary using Firebase Admin SDK
const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Initialize Firebase Admin
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

// This will use Application Default Credentials
if (!admin.apps.length) {
  admin.initializeApp();
}

async function sendDailySummary() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    const targetDate = new Date('2025-10-01');
    const targetEmail = 'con.lawless@gmail.com';
    
    console.log('\n📧 Manually Triggering Daily Summary');
    console.log('═══════════════════════════════════');
    console.log(`Organization ID: ${orgId}`);
    console.log(`Target Date: ${targetDate.toISOString().split('T')[0]}`);
    console.log(`Email: ${targetEmail}\n`);
    
    // Get org data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      throw new Error(`Organization ${orgId} not found`);
    }
    
    const orgData = orgDoc.data();
    console.log(`✅ Found organization: ${orgData.name || orgData.organizationName || orgId}\n`);
    
    // Call the Cloud Function using Firebase Admin
    console.log('⏳ Calling triggerDailySummary function...\n');
    
    // Use the deployed function through admin SDK
    const result = await admin.functions().httpsCallable('triggerDailySummary')({
      orgId: orgId,
      targetDate: targetDate.toISOString()
    });
    
    console.log('📊 Function result:', result.data);
    
    console.log('\n✅ Daily summary sent successfully!');
    console.log(`📧 Check your email at: ${targetEmail}\n`);
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('\nStack trace:', error.stack);
    process.exit(1);
  }
}

// Run the function
sendDailySummary()
  .then(() => {
    console.log('✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  });
