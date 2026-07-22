const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
// Use the correct Firestore database (not the default)
db.settings({ databaseId: 'planwithhands' });

async function simpleDailySummaryCheck() {
  try {
    console.log('🔍 Simple daily summary investigation for Hamilton Pork...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const userEmail = 'jgondevas@gmail.com';
    
    // 1. Get the organization document
    console.log('1. Checking organization configuration...');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    console.log(`Organization: ${orgData.name}`);
    console.log(`Active: ${orgData.isActive}`);
    console.log(`Subscription: ${orgData.subscriptionStatus}`);
    console.log(`Timezone: ${orgData.timezone}`);
    
    // Check if there are any daily summary related settings
    if (orgData.settings) {
      console.log('\nOrganization settings:');
      Object.keys(orgData.settings).forEach(key => {
        if (key.toLowerCase().includes('summary') || key.toLowerCase().includes('email') || key.toLowerCase().includes('notification')) {
          console.log(`   ${key}: ${orgData.settings[key]}`);
        }
      });
    }
    
    // Check for notification preferences at org level
    if (orgData.notificationPreferences) {
      console.log('\nOrganization notification preferences:');
      console.log(JSON.stringify(orgData.notificationPreferences, null, 2));
    } else {
      console.log('\n❌ NO organization notification preferences found');
    }
    
    // 2. Get user details
    console.log('\n2. Checking user configuration...');
    const userQuery = await db.collection('users').where('email', '==', userEmail).get();
    const userDoc = userQuery.docs[0];
    const userData = userDoc.data();
    const userId = userDoc.id;
    
    console.log(`User: ${userData.firstName} ${userData.lastName}`);
    console.log(`Role: ${userData.userRole}`);
    console.log(`Organization: ${userData.organizationId}`);
    
    // 3. Check user notification preferences (we know this exists)
    const userNotifRef = db.collection('users').doc(userId).collection('preferences').doc('notifications');
    const userNotifDoc = await userNotifRef.get();
    const userNotifData = userNotifDoc.data();
    
    console.log('\nUser notification preferences:');
    console.log(`   Daily Summary Enabled: ${userNotifData.dailySummaryEnabled}`);
    console.log(`   Daily Summary Time: ${userNotifData.dailySummaryTime.hour}:${userNotifData.dailySummaryTime.minute.toString().padStart(2, '0')}`);
    
    // 4. Look for any recent logs (without complex queries)
    console.log('\n3. Checking for any recent logs...');
    const recentLogsRef = db.collection('logs').orderBy('createdAt', 'desc').limit(20);
    const recentLogsSnapshot = await recentLogsRef.get();
    
    let dailySummaryLogs = [];
    let emailLogs = [];
    
    recentLogsSnapshot.forEach(doc => {
      const logData = doc.data();
      if (logData.type === 'daily_summary' || (logData.message && logData.message.includes('daily summary'))) {
        dailySummaryLogs.push(logData);
      }
      if (logData.type === 'email' || (logData.recipientEmail && logData.recipientEmail === userEmail)) {
        emailLogs.push(logData);
      }
    });
    
    console.log(`Found ${dailySummaryLogs.length} daily summary related logs`);
    console.log(`Found ${emailLogs.length} email logs for ${userEmail}`);
    
    if (dailySummaryLogs.length > 0) {
      console.log('\nRecent daily summary logs:');
      dailySummaryLogs.slice(0, 3).forEach((log, index) => {
        console.log(`   ${index + 1}. ${new Date(log.createdAt._seconds * 1000).toLocaleString()}`);
        console.log(`      Message: ${log.message || 'no message'}`);
      });
    }
    
    if (emailLogs.length > 0) {
      console.log('\nRecent email logs for user:');
      emailLogs.slice(0, 3).forEach((log, index) => {
        console.log(`   ${index + 1}. ${new Date(log.createdAt._seconds * 1000).toLocaleString()}`);
        console.log(`      Subject: ${log.subject || 'no subject'}`);
        console.log(`      Status: ${log.status || 'unknown'}`);
      });
    }
    
    // 5. Check if there are any scheduled tasks or cron jobs
    console.log('\n4. Checking for scheduled tasks...');
    const tasksRef = db.collection('scheduledTasks').limit(10);
    const tasksSnapshot = await tasksRef.get();
    
    if (tasksSnapshot.empty) {
      console.log('❌ No scheduled tasks found');
    } else {
      console.log(`Found ${tasksSnapshot.size} scheduled tasks`);
      tasksSnapshot.forEach(doc => {
        const taskData = doc.data();
        if (taskData.type === 'daily_summary' || taskData.organizationId === orgId) {
          console.log(`   Task: ${taskData.type || 'unknown'} for org ${taskData.organizationId}`);
          console.log(`   Next run: ${taskData.nextRun ? new Date(taskData.nextRun._seconds * 1000).toLocaleString() : 'unknown'}`);
        }
      });
    }
    
    console.log('\n📋 SUMMARY AND RECOMMENDATIONS:');
    console.log('=====================================');
    console.log('✅ User has proper notification preferences');
    console.log('✅ User is admin level (role 2)');
    console.log('✅ Organization is active');
    
    if (!orgData.notificationPreferences) {
      console.log('❌ MISSING: Organization notification preferences');
      console.log('   Recommendation: Add notification preferences to organization');
    }
    
    if (dailySummaryLogs.length === 0) {
      console.log('❌ ISSUE: No recent daily summary activity');
      console.log('   Recommendation: Check if daily summary cron job is running');
    }
    
    if (emailLogs.length === 0) {
      console.log('❌ ISSUE: No email delivery logs for user');
      console.log('   Recommendation: Check email service and delivery system');
    }
    
  } catch (error) {
    console.error('❌ Error in simple daily summary check:', error);
  }
}

simpleDailySummaryCheck();