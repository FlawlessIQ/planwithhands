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
const USER_ID = 'sXAEgtodreSTrXU0DUpHKEoq0LC3'; // John Gondevas

async function checkNotifications() {
  console.log('\n=== NOTIFICATION INVESTIGATION ===\n');
  
  try {
    // 1. Check userNotifications collection
    console.log('1. CHECKING USER NOTIFICATIONS:');
    console.log(`   User ID: ${USER_ID}`);
    console.log(`   Email: jgondevas@gmail.com\n`);
    
    const userNotificationsRef = db.collection('userNotifications').doc(USER_ID)
      .collection('notifications');
    
    // Get all notifications
    const allNotifs = await userNotificationsRef
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();
    
    console.log(`   Total recent notifications: ${allNotifs.size}\n`);
    
    if (allNotifs.size === 0) {
      console.log('   ❌ NO NOTIFICATIONS FOUND in userNotifications collection!\n');
    } else {
      console.log('   Recent notifications:');
      allNotifs.forEach(doc => {
        const data = doc.data();
        const createdAt = data.createdAt?.toDate();
        console.log(`   - ${data.type || 'unknown'}: ${data.title || 'No title'}`);
        console.log(`     Created: ${createdAt?.toLocaleString() || 'Unknown'}`);
        console.log(`     Read: ${data.readBy?.includes(USER_ID) ? 'Yes' : 'No'}\n`);
      });
    }
    
    // 2. Check for daily_summary type specifically
    console.log('2. CHECKING DAILY SUMMARY NOTIFICATIONS:');
    const dailySummaryNotifs = await userNotificationsRef
      .where('type', '==', 'daily_summary')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    console.log(`   Daily summary notifications found: ${dailySummaryNotifs.size}\n`);
    
    if (dailySummaryNotifs.size === 0) {
      console.log('   ❌ NO daily_summary notifications found!\n');
    } else {
      dailySummaryNotifs.forEach(doc => {
        const data = doc.data();
        const createdAt = data.createdAt?.toDate();
        console.log(`   ✅ Found: ${data.title}`);
        console.log(`      Created: ${createdAt?.toISOString()}`);
        console.log(`      Message: ${data.message?.substring(0, 100)}...`);
        console.log('');
      });
    }
    
    // 3. Check notification outbox in organization
    console.log('3. CHECKING ORGANIZATION NOTIFICATION OUTBOX:');
    const outboxRef = db.collection('organizations').doc(ORG_ID)
      .collection('notificationOutbox');
    
    const recentOutbox = await outboxRef
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    console.log(`   Recent outbox notifications: ${recentOutbox.size}\n`);
    
    if (recentOutbox.size === 0) {
      console.log('   ❌ NO notifications in outbox!\n');
    } else {
      console.log('   Recent outbox entries:');
      recentOutbox.forEach(doc => {
        const data = doc.data();
        const createdAt = data.createdAt?.toDate();
        console.log(`   - ${data.type || 'unknown'}: ${data.title || 'No title'}`);
        console.log(`     Created: ${createdAt?.toLocaleString() || 'Unknown'}`);
        console.log(`     Target: ${data.targetType || 'Unknown'}\n`);
      });
    }
    
    // 4. Check daily_summary_logs to see if function ran
    console.log('4. CHECKING FUNCTION EXECUTION:');
    const today = new Date();
    for (let i = 0; i < 3; i++) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      const dateStr = date.getFullYear() + '-' +
                     String(date.getMonth() + 1).padStart(2, '0') + '-' +
                     String(date.getDate()).padStart(2, '0');
      
      const logDoc = await db.collection('organizations').doc(ORG_ID)
        .collection('daily_summary_logs').doc(dateStr).get();
      
      if (logDoc.exists) {
        const logData = logDoc.data();
        const sentAt = logData.sentAt?.toDate();
        console.log(`   ✅ ${dateStr}: Function executed at ${sentAt?.toLocaleString()}`);
      } else {
        console.log(`   ❌ ${dateStr}: No execution log`);
      }
    }
    
    console.log('\n5. DIAGNOSIS:');
    
    if (dailySummaryNotifs.size === 0 && recentOutbox.size > 0) {
      console.log('\n   🔍 ISSUE: Outbox has notifications but they are not reaching user notifications!');
      console.log('   This suggests a problem with the notification fan-out/delivery system.');
      console.log('   The sendNotificationToAdmins function may not be creating individual user notifications correctly.');
    } else if (dailySummaryNotifs.size === 0 && recentOutbox.size === 0) {
      console.log('\n   🔍 ISSUE: No notifications are being created at all!');
      console.log('   The sendNotificationToAdmins function may not be running or is failing silently.');
      console.log('   Check Cloud Functions logs for errors.');
    } else {
      console.log('\n   ✅ Notifications are being created successfully!');
    }
    
    // 6. Check Cloud Functions logs
    console.log('\n6. NEXT STEPS:');
    console.log('\n   To check Cloud Functions logs, run:');
    console.log('   firebase functions:log --only scheduledDailySummary --limit 50\n');
    console.log('   Look for:');
    console.log('   - "Daily summary sent to X admin(s)"');
    console.log('   - "Error sending notifications"');
    console.log('   - Any error messages during notification creation\n');
    
  } catch (error) {
    console.error('Error:', error);
  }
}

checkNotifications().then(() => {
  console.log('✅ Investigation complete\n');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
