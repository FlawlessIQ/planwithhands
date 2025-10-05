const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

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

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';
const USER_EMAIL = 'jgondevas@gmail.com';

async function checkDailySummarySettings() {
  console.log('\n=== DAILY SUMMARY DIAGNOSTICS ===\n');
  
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
      console.log('   To fix: Enable daily summary in organization settings');
    }
    
    // 2. Find User
    console.log('\n2. USER SETTINGS:');
    const usersSnapshot = await db.collection('users')
      .where('email', '==', USER_EMAIL)
      .where('organizationId', '==', ORG_ID)
      .get();
    
    if (usersSnapshot.empty) {
      console.log(`❌ User ${USER_EMAIL} not found in organization!`);
      return;
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    const userId = userDoc.id;
    
    console.log(`   User ID: ${userId}`);
    console.log(`   Name: ${userData.firstName || ''} ${userData.lastName || ''}`);
    console.log(`   Email: ${userData.email}`);
    console.log(`   Role: ${userData.userRole} (${userData.userRole >= 1 ? 'Admin/Manager' : 'Staff'})`);
    console.log(`   Active: ${userData.isActive ? '✅ YES' : '❌ NO'}`);
    
    if (userData.userRole < 1) {
      console.log('\n⚠️  ISSUE FOUND: User role is STAFF (not admin/manager)');
      console.log('   Daily summaries only sent to admins (role >= 1)');
    }
    
    if (!userData.isActive) {
      console.log('\n⚠️  ISSUE FOUND: User account is INACTIVE');
    }
    
    // 3. Check User Notification Preferences
    console.log('\n3. NOTIFICATION PREFERENCES:');
    const preferencesDoc = await db.collection('users').doc(userId)
      .collection('preferences').doc('notifications').get();
    
    if (!preferencesDoc.exists) {
      console.log('   No notification preferences found (will use defaults)');
      console.log('   Default: dailySummaryEnabled = true');
    } else {
      const prefs = preferencesDoc.data();
      console.log(`   Daily Summary Enabled: ${prefs.dailySummaryEnabled !== false ? '✅ YES' : '❌ NO'}`);
      
      if (prefs.dailySummaryTime) {
        console.log(`   Preferred Time: ${prefs.dailySummaryTime.hour ?? 21}:${String(prefs.dailySummaryTime.minute ?? 0).padStart(2, '0')}`);
      }
      
      if (prefs.summaryPeriod) {
        console.log(`   Period: ${prefs.summaryPeriod}`);
      }
      
      if (prefs.dailySummaryEnabled === false) {
        console.log('\n⚠️  ISSUE FOUND: User has DISABLED daily summary notifications!');
        console.log('   To fix: User needs to enable in their notification preferences');
      }
    }
    
    // 4. Check Recent Summary Logs
    console.log('\n4. RECENT SUMMARY LOGS:');
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
    for (const dateStr of datesToCheck) {
      const logDoc = await db.collection('organizations').doc(ORG_ID)
        .collection('daily_summary_logs').doc(dateStr).get();
      
      if (logDoc.exists) {
        const logData = logDoc.data();
        const sentAt = logData.sentAt?.toDate();
        console.log(`   ✅ ${dateStr}: Sent at ${sentAt?.toISOString() || 'unknown'}`);
      } else {
        console.log(`   ❌ ${dateStr}: NOT sent`);
      }
    }
    
    // 5. Check for Recent Data
    console.log('\n5. CHECKING RECENT DATA (yesterday):');
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.getFullYear() + '-' +
                        String(yesterday.getMonth() + 1).padStart(2, '0') + '-' +
                        String(yesterday.getDate()).padStart(2, '0');
    
    const locationsSnapshot = await db.collection('organizations').doc(ORG_ID)
      .collection('locations').get();
    
    let totalChecklists = 0;
    let totalTasks = 0;
    
    for (const locDoc of locationsSnapshot.docs) {
      const checklistsSnapshot = await db.collection('organizations').doc(ORG_ID)
        .collection('locations').doc(locDoc.id)
        .collection('daily_checklists')
        .where('date', '==', yesterdayStr)
        .get();
      
      totalChecklists += checklistsSnapshot.size;
      
      for (const clDoc of checklistsSnapshot.docs) {
        const tasksSnapshot = await clDoc.ref.collection('tasks').get();
        totalTasks += tasksSnapshot.size;
      }
    }
    
    console.log(`   Date: ${yesterdayStr}`);
    console.log(`   Checklists: ${totalChecklists}`);
    console.log(`   Tasks: ${totalTasks}`);
    
    if (totalTasks === 0) {
      console.log('\n⚠️  NOTE: No task data found for yesterday');
      console.log('   Summaries may be skipped if there\'s no meaningful activity');
    }
    
    // 6. Calculate Next Send Time
    console.log('\n6. NEXT SCHEDULED SEND:');
    if (dailySummarySettings.enabled) {
      const targetHour = dailySummarySettings.hour ?? 17;
      const targetMinute = dailySummarySettings.minute ?? 0;
      const orgTimezone = orgData.timezone || 'America/New_York';
      
      // Use luxon for timezone conversion
      const { DateTime } = require('luxon');
      const orgLocalTime = DateTime.now().setZone(orgTimezone).set({
        hour: targetHour,
        minute: targetMinute,
        second: 0,
        millisecond: 0
      });
      
      const targetUTCTime = orgLocalTime.toUTC();
      const currentUTC = DateTime.now().toUTC();
      
      console.log(`   Local Time (${orgTimezone}): ${targetHour}:${String(targetMinute).padStart(2, '0')}`);
      console.log(`   UTC Time: ${targetUTCTime.hour}:${String(targetUTCTime.minute).padStart(2, '0')}`);
      console.log(`   Current UTC: ${currentUTC.hour}:${String(currentUTC.minute).padStart(2, '0')}`);
      
      // Calculate next run
      let nextRun = orgLocalTime;
      if (DateTime.now().setZone(orgTimezone) >= orgLocalTime) {
        nextRun = nextRun.plus({ days: 1 });
      }
      console.log(`   Next Run: ${nextRun.toFormat('yyyy-MM-dd HH:mm')} ${orgTimezone}`);
    } else {
      console.log('   ❌ Not scheduled (daily summary disabled)');
    }
    
    // 7. Summary
    console.log('\n=== SUMMARY ===');
    const issues = [];
    
    if (!dailySummarySettings.enabled) {
      issues.push('❌ Daily summary is disabled at organization level');
    }
    if (userData.userRole < 1) {
      issues.push('❌ User is not an admin/manager');
    }
    if (!userData.isActive) {
      issues.push('❌ User account is inactive');
    }
    
    const preferencesDoc2 = await db.collection('users').doc(userId)
      .collection('preferences').doc('notifications').get();
    if (preferencesDoc2.exists && preferencesDoc2.data().dailySummaryEnabled === false) {
      issues.push('❌ User has disabled daily summary in preferences');
    }
    
    if (issues.length > 0) {
      console.log('\n🚨 ISSUES FOUND:');
      issues.forEach(issue => console.log(`   ${issue}`));
    } else {
      console.log('\n✅ All settings look correct!');
      console.log('   Emails should be sending to ' + USER_EMAIL);
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

checkDailySummarySettings().then(() => {
  console.log('\n✅ Diagnostic complete\n');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
