const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');
const {DateTime} = require('luxon');

// Initialize Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = new Firestore({ 
  databaseId: 'planwithhands',
  projectId: 'plan-with-hands'
});

const ORG_ID = '3qjYzHagWmfbnMieJ1aj'; // Conor's Pub Group
const USER_EMAIL = 'con.lawless@gmail.com';

async function diagnoseConorsPubGroup() {
  console.log('\n🔍 DIAGNOSING CONOR\'S PUB GROUP DAILY SUMMARY ISSUE');
  console.log('=====================================================\n');
  
  try {
    // 1. Check Organization Settings
    console.log('1. ORGANIZATION SETTINGS:');
    const orgDoc = await db.collection('organizations').doc(ORG_ID).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    
    const orgData = orgDoc.data();
    console.log(`   Organization Name: ${orgData.organizationName || orgData.name || 'Unknown'}`);
    console.log(`   Timezone: ${orgData.timezone || 'Not set (defaults to America/New_York)'}`);
    
    const dailySummarySettings = orgData.dailySummarySettings || {};
    console.log(`   Daily Summary Enabled: ${dailySummarySettings.enabled ? '✅ YES' : '❌ NO'}`);
    console.log(`   Scheduled Time: ${dailySummarySettings.hour ?? 17}:${String(dailySummarySettings.minute ?? 0).padStart(2, '0')}`);
    console.log(`   Summary Period: ${dailySummarySettings.summaryPeriod || 'calendar-day'}`);
    
    if (!dailySummarySettings.enabled) {
      console.log('\n⚠️  ISSUE FOUND: Daily summary is DISABLED for this organization!');
    }
    
    // 2. Calculate when the summary should send
    console.log('\n2. TIMING CALCULATION:');
    const targetHour = dailySummarySettings.hour ?? 17;
    const targetMinute = dailySummarySettings.minute ?? 0;
    const orgTimezone = orgData.timezone || 'America/New_York';
    
    console.log(`   Target time: ${targetHour}:${targetMinute.toString().padStart(2, '0')} ${orgTimezone}`);
    
    // Convert to UTC
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
    console.log(`   Current UTC time: ${DateTime.now().toUTC().toFormat('HH:mm')} UTC`);
    
    // Check if it's the right hour
    const currentUTCHour = DateTime.now().toUTC().hour;
    const isTargetHour = currentUTCHour === targetUTCHour;
    console.log(`   Is target hour now? ${isTargetHour ? '✅ YES' : '❌ NO'}`);
    
    if (!isTargetHour) {
      console.log(`   ⏰ Next run will be at ${targetUTCHour}:00 UTC`);
    }
    
    // 3. Check Recent Summary Logs
    console.log('\n3. RECENT SUMMARY LOGS:');
    const today = new Date();
    const datesToCheck = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      const dateStr = date.getFullYear() + '-' +
                     String(date.getMonth() + 1).padStart(2, '0') + '-' +
                     String(date.getDate()).padStart(2, '0');
      datesToCheck.push(dateStr);
    }
    
    console.log('   Checking last 7 days...');
    let lastSentDate = null;
    for (const dateStr of datesToCheck) {
      const logDoc = await db.collection('organizations').doc(ORG_ID)
        .collection('daily_summary_logs').doc(dateStr).get();
      
      if (logDoc.exists) {
        const logData = logDoc.data();
        const sentAt = logData.sentAt?.toDate();
        console.log(`   ✅ ${dateStr}: Sent at ${sentAt?.toISOString() || 'unknown'}`);
        if (!lastSentDate) lastSentDate = dateStr;
      } else {
        console.log(`   ❌ ${dateStr}: NOT sent`);
      }
    }
    
    if (lastSentDate) {
      const daysSince = datesToCheck.findIndex(d => d === lastSentDate);
      console.log(`\n   ⚠️  Last summary sent: ${lastSentDate} (${daysSince} days ago)`);
      if (daysSince >= 2) {
        console.log(`   🚨 CRITICAL: No summaries for ${daysSince} days!`);
      }
    }
    
    // 4. Check if there's data for recent days
    console.log('\n4. CHECKING RECENT DATA:');
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.getFullYear() + '-' +
                        String(yesterday.getMonth() + 1).padStart(2, '0') + '-' +
                        String(yesterday.getDate()).padStart(2, '0');
    
    const locationsSnapshot = await db.collection('organizations').doc(ORG_ID)
      .collection('locations').get();
    
    let totalChecklists = 0;
    for (const locDoc of locationsSnapshot.docs) {
      const checklistsSnapshot = await db.collection('organizations').doc(ORG_ID)
        .collection('locations').doc(locDoc.id)
        .collection('daily_checklists')
        .where('date', '==', yesterdayStr)
        .get();
      
      totalChecklists += checklistsSnapshot.size;
    }
    
    console.log(`   Date: ${yesterdayStr}`);
    console.log(`   Locations: ${locationsSnapshot.size}`);
    console.log(`   Checklists: ${totalChecklists}`);
    
    if (totalChecklists === 0) {
      console.log('\n⚠️  NOTE: No checklist data found for yesterday');
      console.log('   This might explain why summaries aren\'t being sent');
    } else {
      console.log('\n✅  Data exists for yesterday - summary should have been sent');
    }
    
    // 5. Check User Settings
    console.log('\n5. USER SETTINGS:');
    const usersSnapshot = await db.collection('users')
      .where('email', '==', USER_EMAIL)
      .where('organizationId', '==', ORG_ID)
      .get();
    
    if (usersSnapshot.empty) {
      console.log(`❌ User ${USER_EMAIL} not found in organization!`);
    } else {
      const userDoc = usersSnapshot.docs[0];
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      console.log(`   User ID: ${userId}`);
      console.log(`   Name: ${userData.firstName || ''} ${userData.lastName || ''}`);
      console.log(`   Email: ${userData.email}`);
      console.log(`   Role: ${userData.userRole} (${userData.userRole >= 1 ? 'Admin/Manager' : 'Staff'})`);
      console.log(`   Active: ${userData.isActive ? '✅ YES' : '❌ NO'}`);
      
      if (userData.userRole < 1) {
        console.log('\n⚠️  ISSUE: User role is STAFF (not admin/manager)');
        console.log('   Daily summaries only sent to admins (role >= 1)');
      }
    }
    
    // 6. Check if organization appears in scheduled function logs
    console.log('\n6. SCHEDULED FUNCTION ANALYSIS:');
    console.log('   Checking if this organization is being processed by scheduledDailySummary...');
    console.log('   (Run: firebase functions:log --only scheduledDailySummary | grep "3qjYzHagWmfbnMieJ1aj")');
    
    console.log('\n=== SUMMARY ===');
    const issues = [];
    
    if (!dailySummarySettings.enabled) {
      issues.push('❌ Daily summary is disabled at organization level');
    }
    if (lastSentDate && datesToCheck.findIndex(d => d === lastSentDate) >= 2) {
      issues.push(`🚨 No summaries sent for ${datesToCheck.findIndex(d => d === lastSentDate)} days`);
    }
    if (totalChecklists === 0) {
      issues.push('⚠️  No checklist data found for yesterday');
    }
    
    if (issues.length > 0) {
      console.log('\n🚨 ISSUES FOUND:');
      issues.forEach(issue => console.log(`   ${issue}`));
    } else {
      console.log('\n✅ All settings look correct!');
      console.log('   The issue is likely with the scheduled function not running properly');
    }
    
    console.log('\n💡 RECOMMENDED ACTIONS:');
    console.log('1. Check Cloud Scheduler in Google Cloud Console');
    console.log('2. Verify scheduledDailySummary function is deployed and healthy');
    console.log('3. Check function execution logs for errors');
    console.log('4. Consider manually triggering the summary for missed days');
    
  } catch (error) {
    console.error('Error:', error);
  }
}

diagnoseConorsPubGroup().then(() => {
  console.log('\n✅ Diagnostic complete\n');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});