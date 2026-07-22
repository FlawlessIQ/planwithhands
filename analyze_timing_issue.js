const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: 'https://plan-with-hands.firebaseio.com'
});

const db = admin.firestore();
const planwithhandsDb = admin.app().firestore('planwithhands');

async function analyzeTiming() {
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    console.log('\n=== ANALYZING TIMING HISTORY FOR CONOR\'S PUB GROUP ===\n');
    
    // Get the organization settings
    const orgDoc = await planwithhandsDb.collection('organizations').doc(orgId).get();
    
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    
    const orgData = orgDoc.data();
    
    console.log('Organization:', orgData.name);
    console.log('Daily Summary Enabled:', orgData.dailySummaryEnabled);
    console.log('\n📅 CURRENT SETTINGS:');
    console.log('  Time:', orgData.dailySummaryTime || 'Not set');
    console.log('  Timezone:', orgData.timezone);
    
    // Calculate what UTC hour this corresponds to
    if (orgData.dailySummaryTime) {
      const [hours, minutes] = orgData.dailySummaryTime.split(':').map(Number);
      const { DateTime } = require('luxon');
      
      const localTime = DateTime.fromObject(
        { hour: hours, minute: minutes },
        { zone: orgData.timezone }
      );
      
      const utcTime = localTime.toUTC();
      console.log('  → Converts to UTC:', `${utcTime.hour}:${String(utcTime.minute).padStart(2, '0')} UTC`);
    }
    
    // Check all summary logs
    const logsSnapshot = await planwithhandsDb
      .collection('daily_summary_logs')
      .where('organizationId', '==', orgId)
      .get();
    
    console.log('\n📧 SUMMARY HISTORY:');
    console.log(`  Total summaries ever sent: ${logsSnapshot.size}`);
    
    if (logsSnapshot.size > 0) {
      const sortedDocs = logsSnapshot.docs.sort((a, b) => {
        const aTime = a.data().sentAt?.toDate() || new Date(0);
        const bTime = b.data().sentAt?.toDate() || new Date(0);
        return bTime - aTime;
      });
      
      console.log('\n  Last 5 summaries:');
      for (let i = 0; i < Math.min(5, sortedDocs.length); i++) {
        const logData = sortedDocs[i].data();
        const sentAt = logData.sentAt?.toDate();
        console.log(`    ${i + 1}. ${logData.summaryDate} - Sent: ${sentAt?.toLocaleString('en-US', { timeZone: orgData.timezone })}`);
      }
    }
    
    // Now let's check what time you originally set it to this morning
    console.log('\n🔍 CHECKING FOR TIMING CHANGES:');
    console.log('  Current setting:', orgData.dailySummaryTime);
    console.log('  Note: We cannot see historical changes, but based on logs:');
    
    if (logsSnapshot.size === 0) {
      console.log('\n❌ NO SUMMARIES HAVE EVER BEEN LOGGED FOR THIS ORG');
      console.log('   This means the scheduled function has never successfully sent a summary.');
      console.log('   This could be because:');
      console.log('   1. The dailySummaryEnabled was recently turned on');
      console.log('   2. The time setting was incorrect');
      console.log('   3. The scheduled function had an issue');
    }
    
    console.log('\n⏰ TIMING ANALYSIS:');
    console.log('  The scheduled function runs every hour at :00 UTC');
    console.log('  It checks if current hour matches target hour AND we\'re past target minute');
    console.log('  Example: If target is 21:53 UTC, it will send at 22:00 UTC');
    console.log('  This means there can be a delay of 0-60 minutes after your set time');
    
  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

analyzeTiming();
