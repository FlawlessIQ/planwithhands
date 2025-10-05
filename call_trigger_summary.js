const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://plan-with-hands.firebaseio.com'
});

const functions = admin.functions();

async function callTriggerDailySummary() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    const targetDate = '2025-10-01';
    
    console.log(`\n🔄 Calling triggerDailySummary function`);
    console.log(`   Organization: ${orgId}`);
    console.log(`   Date: ${targetDate}`);
    console.log(`   Email override: con.lawless@gmail.com\n`);
    
    // Call the deployed function
    const triggerFunction = functions.httpsCallable('triggerDailySummary');
    
    const result = await triggerFunction({
      orgId: orgId,
      targetDate: targetDate
    });
    
    console.log('\n✅ Function executed successfully!');
    console.log('📧 Email should be sent to con.lawless@gmail.com');
    console.log('\n📊 Result:', JSON.stringify(result.data, null, 2));
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error calling function:', error);
    if (error.details) {
      console.error('Details:', error.details);
    }
    process.exit(1);
  }
}

callTriggerDailySummary();
