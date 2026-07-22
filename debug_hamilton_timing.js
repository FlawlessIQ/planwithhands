const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');
const {DateTime} = require('luxon');

// Initialize Admin SDK with application default credentials
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = new Firestore({ 
  databaseId: 'planwithhands',
  projectId: 'plan-with-hands'
});

async function debugHamiltonTiming() {
  console.log('\n🕐 Debugging Hamilton Pork daily summary timing...\n');
  
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const currentUTCHour = 19; // Current UTC hour from the logs
    
    // Get Hamilton Pork data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    console.log('1. Organization Settings:');
    console.log(`   Daily Summary Enabled: ${orgData.dailySummarySettings?.enabled}`);
    console.log(`   Target Hour: ${orgData.dailySummarySettings?.hour ?? 17}`);
    console.log(`   Target Minute: ${orgData.dailySummarySettings?.minute ?? 0}`);
    console.log(`   Organization Timezone: ${orgData.timezone || 'America/New_York'}`);
    
    // Reproduce the exact timing logic from the Cloud Function
    const dailySummarySettings = orgData.dailySummarySettings;
    if (!dailySummarySettings || !dailySummarySettings.enabled) {
      console.log('\n❌ ISSUE: Daily summary is disabled!');
      return;
    }
    
    const targetHour = dailySummarySettings.hour ?? 17;
    const targetMinute = dailySummarySettings.minute ?? 0;
    const orgTimezone = orgData.timezone || "America/New_York";
    
    console.log('\n2. Timing Calculation:');
    console.log(`   Target time: ${targetHour}:${targetMinute.toString().padStart(2, '0')} ${orgTimezone}`);
    
    // Convert the organization's target time to UTC
    const orgLocalTime = DateTime.now().setZone(orgTimezone).set({
      hour: targetHour,
      minute: targetMinute,
      second: 0,
      millisecond: 0
    });
    
    const targetUTCTime = orgLocalTime.toUTC();
    const targetUTCHour = targetUTCTime.hour;
    const targetUTCMinute = targetUTCTime.minute;
    
    console.log(`   Target UTC time: ${targetUTCHour}:${targetUTCMinute.toString().padStart(2, '0')} UTC`);
    console.log(`   Current UTC hour: ${currentUTCHour}`);
    
    // Check if we're at the right UTC hour
    const isTargetHour = currentUTCHour === targetUTCHour;
    console.log(`   Is target hour? ${isTargetHour ? '✅ YES' : '❌ NO'}`);
    
    if (isTargetHour) {
      console.log('   ✅ Hamilton Pork SHOULD be processed at this hour');
    } else {
      console.log('   ❌ Hamilton Pork should NOT be processed at this hour');
      console.log(`   Expected to run at ${targetUTCHour}:00 UTC`);
    }
    
    // Check the "already sent" status for October 14th
    console.log('\n3. Already Sent Check:');
    const dateStr = '2025-10-14';
    const logDoc = await db
      .collection('organizations')
      .doc(orgId)
      .collection('daily_summary_logs')
      .doc(dateStr)
      .get();
    
    console.log(`   Summary already sent for ${dateStr}: ${logDoc.exists ? '✅ YES' : '❌ NO'}`);
    
    if (logDoc.exists) {
      const logData = logDoc.data();
      console.log(`   Sent at: ${logData.sentAt?.toDate()?.toISOString()}`);
      console.log('\n🔍 This explains why Hamilton Pork was skipped!');
      console.log('   The function found an existing summary log for today.');
    }
    
  } catch (error) {
    console.error('❌ Error during timing debug:', error);
  }
}

debugHamiltonTiming().then(() => {
  console.log('\n✅ Hamilton timing debug complete');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});