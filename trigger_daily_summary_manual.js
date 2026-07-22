const admin = require('firebase-admin');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function triggerDailySummaryManual() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    // Calculate yesterday's date
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split('T')[0]; // YYYY-MM-DD format
    
    console.log(`🔄 Triggering daily summary for org: ${orgId}`);
    console.log(`📅 Target date: ${dateStr} (yesterday)`);
    
    // First, remove the "already sent" marker so we can resend
    const logRef = db.collection('organizations').doc(orgId).collection('daily_summary_logs').doc(dateStr);
    const logDoc = await logRef.get();
    
    if (logDoc.exists) {
      console.log(`🗑️  Removing existing daily summary log for ${dateStr}`);
      await logRef.delete();
    } else {
      console.log(`ℹ️  No existing daily summary log found for ${dateStr}`);
    }
    
    // Import the Cloud Function directly and call it
    console.log(`📡 Importing and calling daily summary function...`);
    
    // Import the functions from the built functions directory
    const { generateAndSendDailySummary } = require('./functions/lib/scheduledDailySummary.js');
    
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.exists ? orgDoc.data() : {};
    
    console.log(`🏢 Organization data loaded, generating summary...`);
    
    // Call the function directly
    await generateAndSendDailySummary(orgId, yesterday, orgData);
    
    console.log(`✅ Daily summary generated and sent successfully!`);
    console.log(`📱 Check your notifications in the app to see the daily summary.`);
    
  } catch (error) {
    console.error('❌ Error triggering daily summary:', error);
    console.log('💡 The function might not be built or accessible from this context');
  }
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