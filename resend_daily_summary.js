const admin = require('firebase-admin');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

async function triggerDailySummaryManual() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    // Calculate yesterday's date
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split('T')[0]; // YYYY-MM-DD format
    
    console.log(`🔄 Triggering daily summary for org: ${orgId}`);
    console.log(`📅 Target date: ${dateStr} (yesterday)`);
    
    // Use Firebase Admin to call the Cloud Function via HTTP
    const fetch = require('node-fetch');
    
    // Get the project ID
    const projectId = 'plan-with-hands';
    const functionUrl = `https://us-central1-${projectId}.cloudfunctions.net/triggerDailySummary`;
    
    console.log(`📡 Calling Cloud Function at: ${functionUrl}`);
    
    // We need to get an auth token to call the function
    const { GoogleAuth } = require('google-auth-library');
    const auth = new GoogleAuth();
    const client = await auth.getIdTokenClient(functionUrl);
    
    const response = await client.request({
      url: functionUrl,
      method: 'POST',
      data: {
        data: {
          orgId: orgId,
          targetDate: yesterday.toISOString()
        }
      }
    });
    
    console.log(`✅ Daily summary triggered successfully!`);
    console.log(`📧 Response:`, response.data);
    console.log(`📱 Check your notifications in the app to see the daily summary.`);
    
  } catch (error) {
    console.error('❌ Error triggering daily summary:', error);
    
    // Alternative approach: Use Firebase CLI
    console.log('\n💡 Alternative: You can also trigger manually using Firebase CLI:');
    console.log(`firebase functions:shell`);
    console.log(`triggerDailySummary({orgId: '${orgId}', targetDate: '${yesterday.toISOString()}'})`);
  }
}

// Run the function
triggerDailySummaryManual().then(() => {
  console.log('🏁 Script completed');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});