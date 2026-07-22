const admin = require('firebase-admin');

// Initialize Firebase Admin with the planwithhands database
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com/'
  });
}

// Use the planwithhands database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function debugTimingIssue(orgId) {
  console.log(`🕐 Debug Timing Issue for Organization: ${orgId}`);
  
  try {
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    
    const orgData = orgDoc.data();
    const settings = orgData.dailySummarySettings;
    const orgTimezone = orgData.timezone || "America/New_York";
    
    console.log('\n📊 Organization Details:');
    console.log(`   Name: ${orgData.name || orgData.organizationName || 'Unknown'}`);
    console.log(`   Timezone: ${orgTimezone}`);
    
    if (settings) {
      console.log('\n⚙️ Daily Summary Settings:');
      console.log(`   Enabled: ${settings.enabled}`);
      console.log(`   Target Time: ${settings.hour}:${String(settings.minute).padStart(2, '0')}`);
      console.log(`   Last Updated: ${settings.updatedAt?.toDate()}`);
    } else {
      console.log('\n❌ No daily summary settings found');
      return;
    }
    
    console.log('\n⏰ Time Analysis:');
    
    // Cloud Function runs at 21:00 UTC
    const cloudFunctionUTC = new Date();
    cloudFunctionUTC.setUTCHours(21, 0, 0, 0);
    console.log(`   Cloud Function runs at: ${cloudFunctionUTC.toISOString()} (21:00 UTC)`);
    
    // Convert to organization timezone
    const { DateTime } = require('luxon');
    const cloudFunctionOrgTime = DateTime.fromJSDate(cloudFunctionUTC).setZone(orgTimezone);
    console.log(`   In ${orgTimezone}: ${cloudFunctionOrgTime.toFormat('HH:mm')} (${cloudFunctionOrgTime.toFormat('h:mm a')})`);
    
    // Target time in org timezone
    const targetTime = DateTime.now().setZone(orgTimezone).set({ 
      hour: settings.hour, 
      minute: settings.minute,
      second: 0,
      millisecond: 0
    });
    console.log(`   Target time: ${targetTime.toFormat('HH:mm')} (${targetTime.toFormat('h:mm a')})`);
    
    // Calculate difference
    const cloudFunctionMinutes = cloudFunctionOrgTime.hour * 60 + cloudFunctionOrgTime.minute;
    const targetMinutes = settings.hour * 60 + settings.minute;
    const difference = Math.abs(cloudFunctionMinutes - targetMinutes);
    
    console.log(`\n🔍 Time Difference Analysis:`);
    console.log(`   Function time: ${cloudFunctionOrgTime.toFormat('HH:mm')} = ${cloudFunctionMinutes} minutes from midnight`);
    console.log(`   Target time: ${targetTime.toFormat('HH:mm')} = ${targetMinutes} minutes from midnight`);
    console.log(`   Difference: ${difference} minutes`);
    console.log(`   Window: ±30 minutes`);
    
    if (difference <= 30) {
      console.log(`✅ WITHIN WINDOW: Summary should send when function runs`);
    } else {
      console.log(`❌ OUTSIDE WINDOW: Summary will NOT send`);
      console.log(`   Need to adjust either:`);
      console.log(`   1. Cloud Function schedule to run closer to ${targetTime.toFormat('HH:mm')} UTC`);
      console.log(`   2. Organization time to be closer to ${cloudFunctionOrgTime.toFormat('HH:mm')}`);
    }
    
    console.log('\n🔧 Solutions:');
    
    if (difference > 30) {
      console.log('❌ Current setup won\'t work automatically');
      console.log('💡 Option 1: Change your daily summary time to around ' + cloudFunctionOrgTime.toFormat('h:mm a'));
      console.log('💡 Option 2: Manually trigger the summary for testing');
      console.log('💡 Option 3: Modify Cloud Function schedule');
    } else {
      console.log('✅ Should work! Check Cloud Function logs for errors');
    }
    
    // Current time analysis
    const now = DateTime.now().setZone(orgTimezone);
    console.log(`\n🕐 Current Time Analysis:`);
    console.log(`   Current time in ${orgTimezone}: ${now.toFormat('HH:mm')} (${now.toFormat('h:mm a')})`);
    console.log(`   Minutes until target: ${targetMinutes - (now.hour * 60 + now.minute)} minutes`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Get orgId from command line argument
const orgId = process.argv[2];
if (!orgId) {
  console.log('Usage: node debug_timing_issue.js <orgId>');
  process.exit(1);
}

debugTimingIssue(orgId).then(() => {
  console.log('\n✅ Debug complete');
  process.exit(0);
}).catch(error => {
  console.error('❌ Script error:', error);
  process.exit(1);
});