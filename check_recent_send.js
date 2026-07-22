const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: 'https://plan-with-hands.firebaseio.com'
});

const db = admin.firestore();
// Use the planwithhands database
const planwithhandsDb = admin.app().firestore('planwithhands');

async function checkRecentSend() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    console.log('\n=== CHECKING MOST RECENT SUMMARY SEND ===\n');
    
    // Check the most recent daily_summary_logs entry
    const logsSnapshot = await planwithhandsDb
      .collection('daily_summary_logs')
      .where('organizationId', '==', orgId)
      .limit(50)
      .get();
    
    if (logsSnapshot.empty) {
      console.log('❌ No logs found');
      return;
    }
    
    // Sort by sentAt manually
    const sortedDocs = logsSnapshot.docs.sort((a, b) => {
      const aTime = a.data().sentAt?.toDate() || new Date(0);
      const bTime = b.data().sentAt?.toDate() || new Date(0);
      return bTime - aTime;
    });
    
    const logDoc = sortedDocs[0];
    const logData = logDoc.data();
    
    console.log('📧 MOST RECENT SUMMARY:');
    console.log('  Log ID:', logDoc.id);
    console.log('  Sent At:', logData.sentAt?.toDate());
    console.log('  Summary Date:', logData.summaryDate);
    console.log('  Recipients:', logData.recipientCount || 'unknown');
    console.log('  Triggered By:', logData.triggeredBy || 'scheduled');
    
    // Check if this was in the last hour
    const sentAt = logData.sentAt?.toDate();
    const now = new Date();
    const minutesAgo = Math.floor((now - sentAt) / 1000 / 60);
    
    console.log('\n⏰ TIMING:');
    console.log('  Sent:', minutesAgo, 'minutes ago');
    console.log('  Current time:', now.toISOString());
    
    if (minutesAgo < 10) {
      console.log('\n✅ THIS JUST HAPPENED! (within last 10 minutes)');
      if (logData.triggeredBy === 'manual') {
        console.log('🔧 This was a MANUAL TRIGGER');
      } else {
        console.log('📅 This was the SCHEDULED function working!');
      }
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    process.exit(0);
  }
}

checkRecentSend();
