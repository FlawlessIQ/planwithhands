const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: 'https://plan-with-hands.firebaseio.com'
});

const db = admin.firestore();
// Use the planwithhands database
const planwithhandsDb = admin.app().firestore('planwithhands');

async function checkRecentLogs() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    console.log('\n=== CHECKING ALL RECENT SUMMARY LOGS ===\n');
    
    // Get ALL logs for this org
    const logsSnapshot = await planwithhandsDb
      .collection('daily_summary_logs')
      .where('organizationId', '==', orgId)
      .get();
    
    console.log(`Found ${logsSnapshot.size} total logs for this organization\n`);
    
    if (logsSnapshot.empty) {
      console.log('❌ No logs found at all');
      return;
    }
    
    // Sort and show the last 3
    const sortedDocs = logsSnapshot.docs.sort((a, b) => {
      const aTime = a.data().sentAt?.toDate() || new Date(0);
      const bTime = b.data().sentAt?.toDate() || new Date(0);
      return bTime - aTime;
    });
    
    console.log('📧 LAST 3 SUMMARIES SENT:\n');
    
    for (let i = 0; i < Math.min(3, sortedDocs.length); i++) {
      const logDoc = sortedDocs[i];
      const logData = logDoc.data();
      const sentAt = logData.sentAt?.toDate();
      const now = new Date();
      const minutesAgo = Math.floor((now - sentAt) / 1000 / 60);
      
      console.log(`${i + 1}. ${logData.summaryDate}`);
      console.log(`   Sent: ${sentAt?.toISOString()} (${minutesAgo} min ago)`);
      console.log(`   Recipients: ${logData.recipientCount || 'unknown'}`);
      console.log(`   Method: ${logData.triggeredBy || 'scheduled'}`);
      
      if (minutesAgo < 10) {
        console.log(`   ✅ JUST SENT!`);
      }
      console.log();
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    process.exit(0);
  }
}

checkRecentLogs();
