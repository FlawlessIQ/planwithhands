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

async function checkDailySummarySystem() {
  try {
    console.log('🔍 Investigating daily summary email system...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const userEmail = 'jgondevas@gmail.com';
    
    // 1. Check recent daily summary logs
    console.log('1. Checking recent daily summary logs...');
    const logsRef = db.collection('logs').where('organizationId', '==', orgId)
      .where('type', '==', 'daily_summary')
      .orderBy('createdAt', 'desc')
      .limit(10);
    
    const logsSnapshot = await logsRef.get();
    
    if (logsSnapshot.empty) {
      console.log('❌ No daily summary logs found for Hamilton Pork');
    } else {
      console.log(`✅ Found ${logsSnapshot.size} daily summary logs:`);
      logsSnapshot.forEach((doc, index) => {
        const logData = doc.data();
        console.log(`   ${index + 1}. ${new Date(logData.createdAt._seconds * 1000).toLocaleString()}`);
        console.log(`      Status: ${logData.status || 'unknown'}`);
        console.log(`      Message: ${logData.message || 'no message'}`);
        if (logData.recipientCount) {
          console.log(`      Recipients: ${logData.recipientCount}`);
        }
        if (logData.errors) {
          console.log(`      Errors: ${logData.errors.length}`);
        }
        console.log('');
      });
    }
    
    // 2. Check email delivery logs specifically for jgondevas@gmail.com
    console.log('2. Checking email delivery logs for jgondevas@gmail.com...');
    const emailLogsRef = db.collection('logs')
      .where('recipientEmail', '==', userEmail)
      .where('type', '==', 'email')
      .orderBy('createdAt', 'desc')
      .limit(10);
    
    const emailLogsSnapshot = await emailLogsRef.get();
    
    if (emailLogsSnapshot.empty) {
      console.log('❌ No email logs found for jgondevas@gmail.com');
    } else {
      console.log(`✅ Found ${emailLogsSnapshot.size} email logs:`);
      emailLogsSnapshot.forEach((doc, index) => {
        const logData = doc.data();
        console.log(`   ${index + 1}. ${new Date(logData.createdAt._seconds * 1000).toLocaleString()}`);
        console.log(`      Template: ${logData.templateId || 'unknown'}`);
        console.log(`      Status: ${logData.status || 'unknown'}`);
        console.log(`      Subject: ${logData.subject || 'no subject'}`);
        if (logData.error) {
          console.log(`      Error: ${logData.error}`);
        }
        console.log('');
      });
    }
    
    // 3. Check scheduled functions/cron jobs
    console.log('3. Checking for scheduled daily summary entries...');
    const scheduledRef = db.collection('scheduledTasks')
      .where('organizationId', '==', orgId)
      .where('type', '==', 'daily_summary');
    
    const scheduledSnapshot = await scheduledRef.get();
    
    if (scheduledSnapshot.empty) {
      console.log('❌ No scheduled daily summary tasks found');
    } else {
      console.log(`✅ Found ${scheduledSnapshot.size} scheduled tasks:`);
      scheduledSnapshot.forEach((doc, index) => {
        const taskData = doc.data();
        console.log(`   ${index + 1}. Task ID: ${doc.id}`);
        console.log(`      Next Run: ${new Date(taskData.nextRun._seconds * 1000).toLocaleString()}`);
        console.log(`      Status: ${taskData.status || 'unknown'}`);
        console.log(`      Time: ${taskData.time?.hour || 'unknown'}:${(taskData.time?.minute || 0).toString().padStart(2, '0')}`);
        console.log('');
      });
    }
    
    // 4. Check organization settings that might affect email delivery
    console.log('4. Checking organization settings...');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    console.log('Organization daily summary settings:');
    console.log(`   Subscription Status: ${orgData.subscriptionStatus}`);
    console.log(`   Is Active: ${orgData.isActive}`);
    console.log(`   Timezone: ${orgData.timezone}`);
    
    if (orgData.settings?.emailsEnabled !== undefined) {
      console.log(`   Emails Enabled: ${orgData.settings.emailsEnabled}`);
    } else {
      console.log('   ⚠️  No emailsEnabled setting found');
    }
    
    if (orgData.settings?.dailySummaryEnabled !== undefined) {
      console.log(`   Daily Summary Enabled: ${orgData.settings.dailySummaryEnabled}`);
    } else {
      console.log('   ⚠️  No dailySummaryEnabled setting found in org');
    }
    
    // 5. Check user's specific settings that we know exist
    console.log('\n5. Confirming user settings...');
    const userDoc = await db.collection('users').where('email', '==', userEmail).get();
    const user = userDoc.docs[0];
    const userId = user.id;
    
    const userNotifRef = db.collection('users').doc(userId).collection('preferences').doc('notifications');
    const userNotifDoc = await userNotifRef.get();
    const userNotifData = userNotifDoc.data();
    
    console.log('User notification settings:');
    console.log(`   Daily Summary Enabled: ${userNotifData.dailySummaryEnabled}`);
    console.log(`   Daily Summary Time: ${userNotifData.dailySummaryTime.hour}:${userNotifData.dailySummaryTime.minute.toString().padStart(2, '0')}`);
    console.log(`   User Role: ${user.data().userRole}`);
    
    // 6. Check Cloud Functions deployment status
    console.log('\n6. Looking for recent function execution logs...');
    const functionLogsRef = db.collection('logs')
      .where('source', '==', 'cloud_function')
      .where('function', '==', 'sendDailySummaries')
      .orderBy('createdAt', 'desc')
      .limit(5);
    
    const functionLogsSnapshot = await functionLogsRef.get();
    
    if (functionLogsSnapshot.empty) {
      console.log('❌ No cloud function logs found for sendDailySummaries');
    } else {
      console.log(`✅ Found ${functionLogsSnapshot.size} function execution logs:`);
      functionLogsSnapshot.forEach((doc, index) => {
        const logData = doc.data();
        console.log(`   ${index + 1}. ${new Date(logData.createdAt._seconds * 1000).toLocaleString()}`);
        console.log(`      Status: ${logData.status || 'unknown'}`);
        console.log(`      Duration: ${logData.executionTime || 'unknown'}ms`);
        if (logData.error) {
          console.log(`      Error: ${logData.error}`);
        }
        console.log('');
      });
    }
    
    console.log('\n📋 DIAGNOSIS SUMMARY:');
    console.log('====================');
    console.log('User has proper notification preferences set:');
    console.log(`   ✅ dailySummaryEnabled: ${userNotifData.dailySummaryEnabled}`);
    console.log(`   ✅ dailySummaryTime: ${userNotifData.dailySummaryTime.hour}:${userNotifData.dailySummaryTime.minute.toString().padStart(2, '0')}`);
    console.log(`   ✅ User Role ${user.data().userRole} (admin level)`);
    console.log('\nPossible issues to investigate:');
    console.log('   1. No organization-level notification preferences');
    console.log('   2. Cloud function not running or failing');
    console.log('   3. Email delivery service issues');
    console.log('   4. Missing scheduled task for this organization');
    
  } catch (error) {
    console.error('❌ Error checking daily summary system:', error);
  }
}

checkDailySummarySystem();