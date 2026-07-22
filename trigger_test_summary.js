const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function triggerSummary() {
  console.log('\n=== MANUALLY TRIGGERING DAILY SUMMARY ===\n');
  console.log(`Organization: ${ORG_ID} (Hamilton Pork)`);
  console.log(`Target Date: Today (${new Date().toDateString()})\n`);
  
  try {
    // Call the Cloud Function via HTTP
    const functions = admin.functions();
    const triggerDailySummary = functions.httpsCallable('triggerDailySummary');
    
    const result = await triggerDailySummary({ orgId: ORG_ID });
    
    console.log('✅ Success!');
    console.log('Response:', result.data);
    console.log('\nCheck:');
    console.log('1. User notifications in the app');
    console.log('2. Email inbox for jgondevas@gmail.com');
    console.log('3. SendGrid dashboard for delivery status\n');
    
  } catch (error) {
    console.error('❌ Error triggering daily summary:', error.message);
    if (error.details) {
      console.error('Details:', error.details);
    }
  }
}

triggerSummary().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
