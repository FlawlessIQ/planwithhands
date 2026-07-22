const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
// Use the correct Firestore database (not the default)
db.settings({ databaseId: 'planwithhands' });

async function debugUserNotifications() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const userEmail = 'jgondevas@gmail.com';
  console.log(`🔍 === DEBUG NOTIFICATIONS FOR ${userEmail} ===\n`);
  
  try {
    // 1. Find the user by email
    console.log('👤 Step 1: Finding User');
    const usersQuery = await db.collection('users')
      .where('email', '==', userEmail)
      .limit(1)
      .get();
    
    if (usersQuery.empty) {
      console.log(`❌ No user found with email: ${userEmail}`);
      return;
    }
    
    const userDoc = usersQuery.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    console.log(`   Found user: ${userData.firstName} ${userData.lastName}`);
    console.log(`   User ID: ${userId}`);
    console.log(`   Organization ID: ${userData.organizationId}`);
    console.log(`   User Role: ${userData.userRole}`);
    console.log(`   Active: ${userData.isActive}`);
    
    if (userData.organizationId !== orgId) {
      console.log(`   ⚠️  User belongs to different org: ${userData.organizationId} vs ${orgId}`);
    }
    
    // 2. Check user notifications collection structure
    console.log(`\n📬 Step 2: User Notifications Collection`);
    
    // Check if user has a notifications document
    const userNotificationsDoc = await db.collection('userNotifications').doc(userId).get();
    
    if (!userNotificationsDoc.exists) {
      console.log(`   ❌ No userNotifications document exists for user ${userId}`);
      console.log(`   🔧 This might be why notifications aren't appearing!`);
      
      // Create the document
      console.log(`   🛠️  Creating userNotifications document...`);
      await db.collection('userNotifications').doc(userId).set({
        userId: userId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`   ✅ Created userNotifications document`);
    } else {
      console.log(`   ✅ userNotifications document exists`);
      console.log(`   Document data:`, userNotificationsDoc.data());
    }
    
    // 3. Check all notifications in the subcollection
    console.log(`\n📋 Step 3: All Notifications`);
    let allNotificationsQuery;
    try {
      allNotificationsQuery = await db.collection('userNotifications')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();
      
      console.log(`   Found ${allNotificationsQuery.size} total notifications`);
      
      allNotificationsQuery.forEach((doc, index) => {
        const data = doc.data();
        const createdAt = data.createdAt?.toDate() || 'No timestamp';
        console.log(`   ${index + 1}. ${data.type || 'unknown'}: ${data.title || 'No title'}`);
        console.log(`      Created: ${createdAt}`);
        console.log(`      Read by: ${data.readBy?.length || 0} users`);
        console.log(`      Archived by: ${data.archivedBy?.length || 0} users`);
      });
      
    } catch (error) {
      console.log(`   ❌ Error querying notifications: ${error.message}`);
      
      // Check if it's an index issue
      if (error.message.includes('index')) {
        console.log(`   🔧 Missing Firestore index - this prevents querying notifications`);
        console.log(`   📝 Create index: userNotifications/{userId}/notifications on createdAt DESC`);
      }
    }
    
    // 4. Check daily summary notifications specifically
    console.log(`\n📊 Step 4: Daily Summary Notifications`);
    let dailySummaryQuery;
    try {
      dailySummaryQuery = await db.collection('userNotifications')
        .doc(userId)
        .collection('notifications')
        .where('type', '==', 'daily_summary')
        .limit(5)
        .get();
      
      console.log(`   Found ${dailySummaryQuery.size} daily summary notifications`);
      
      if (dailySummaryQuery.size === 0) {
        console.log(`   🚨 NO DAILY SUMMARY NOTIFICATIONS FOUND!`);
        console.log(`   This explains why they don't appear in the inbox`);
      } else {
        dailySummaryQuery.forEach((doc, index) => {
          const data = doc.data();
          const createdAt = data.createdAt?.toDate() || 'No timestamp';
          console.log(`   ${index + 1}. Daily Summary: ${data.title || 'No title'}`);
          console.log(`      Created: ${createdAt}`);
          console.log(`      Org ID: ${data.orgId || 'Missing'}`);
          console.log(`      Target Type: ${data.targetType || 'Missing'}`);
          console.log(`      Target ID: ${data.targetId || 'Missing'}`);
        });
      }
      
    } catch (error) {
      console.log(`   ❌ Error querying daily summaries: ${error.message}`);
      dailySummaryQuery = { size: 0 }; // Set default for later reference
    }
    
    // 5. Check recent outbox notifications that should have been sent to this user
    console.log(`\n📤 Step 5: Outbox Notifications (Should Create User Notifications)`);
    
    const recentDates = ['2025-09-24', '2025-09-23', '2025-09-22'];
    
    for (const dateStr of recentDates) {
      console.log(`\n   📅 Checking outbox for ${dateStr}:`);
      
      const outboxQuery = await db.collection('organizations')
        .doc(orgId)
        .collection('notificationOutbox')
        .where('type', '==', 'daily_summary')
        .get();
      
      console.log(`      Found ${outboxQuery.size} daily_summary outbox notifications`);
      
      outboxQuery.docs.slice(0, 3).forEach((doc, index) => {
        const data = doc.data();
        const createdAt = data.createdAt?.toDate() || 'No timestamp';
        console.log(`      ${index + 1}. ${data.title || 'No title'}`);
        console.log(`         Created: ${createdAt}`);
        console.log(`         Target Type: ${data.targetType || 'Missing'}`);
      });
    }
    
    // 6. Check if notification fan-out function is working
    console.log(`\n⚙️  Step 6: Notification System Analysis`);
    console.log(`   The flow should be:`);
    console.log(`   1. Daily summary service creates outbox notification`);
    console.log(`   2. Cloud Function detects new outbox notification`);
    console.log(`   3. Function creates individual user notifications for admins`);
    console.log(`   4. User sees notification in their inbox`);
    console.log(`   `);
    console.log(`   🔍 Based on the investigation:`);
    
    if (allNotificationsQuery && allNotificationsQuery.size === 0) {
      console.log(`   🚨 PRIMARY ISSUE: No notifications found in user's collection`);
      console.log(`   💡 LIKELY CAUSE: Fan-out function not working or user not being targeted`);
    } else if (dailySummaryQuery && dailySummaryQuery.size === 0) {
      console.log(`   🚨 PRIMARY ISSUE: No daily_summary notifications found`);
      console.log(`   💡 LIKELY CAUSE: User not being included in admin targeting logic`);
    } else {
      console.log(`   ✅ User has notifications, check app filtering logic`);
    }
    
    // 7. Manual notification test
    console.log(`\n🧪 Step 7: Manual Test Notification`);
    console.log(`   Creating a test notification for debugging...`);
    
    const testNotificationRef = db.collection('userNotifications')
      .doc(userId)
      .collection('notifications')
      .doc();
    
    const testData = {
      userId: userId,
      orgId: orgId,
      type: 'test_debug',
      title: 'Debug Test Notification',
      message: 'This is a test notification created during debugging.',
      readBy: [],
      archivedBy: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetType: 'user',
      targetId: userId,
    };
    
    await testNotificationRef.set(testData);
    console.log(`   ✅ Created test notification with ID: ${testNotificationRef.id}`);
    console.log(`   📱 Check if this appears in the app inbox`);
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
  }
}

debugUserNotifications().then(() => {
  console.log('\n✅ User notification debug completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Debug failed:', error);
  process.exit(1);
});