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

async function manualTriggerDailySummary() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const targetDate = '2025-09-24';
  
  console.log(`🚀 === MANUALLY TRIGGERING DAILY SUMMARY ===`);
  console.log(`   Organization: ${orgId}`);
  console.log(`   Target Date: ${targetDate}\n`);
  
  try {
    // Let's manually create a notification to test the system
    console.log('🧪 Creating manual notification to test the system...');
    
    const userEmail = 'jgondevas@gmail.com';
    const usersQuery = await db.collection('users')
      .where('email', '==', userEmail)
      .limit(1)
      .get();
    
    if (usersQuery.empty) {
      console.log(`❌ User ${userEmail} not found`);
      return;
    }
    
    const userId = usersQuery.docs[0].id;
    const userData = usersQuery.docs[0].data();
    
    console.log(`   Found user: ${userData.firstName} ${userData.lastName} (${userId})`);
    
    // Create an outbox notification to test the fan-out system
    console.log('\n📤 Creating outbox notification...');
    
    const outboxRef = db.collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .doc();
    
    const outboxData = {
      title: 'Manual Test Daily Summary - Sept 24, 2025',
      message: '🧪 This is a manual test notification to debug the daily summary system.\n\n📊 Test Results:\n• System can create notifications ✅\n• User targeting works ✅\n• Outbox fan-out function will process this\n\n📱 If you see this in your app, the notification system is working correctly!',
      type: 'daily_summary',
      targetType: 'all_users',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    };
    
    await outboxRef.set(outboxData);
    console.log(`   ✅ Created outbox notification with ID: ${outboxRef.id}`);
    console.log(`   🔄 This should trigger the onNotificationOutboxCreated function`);
    
    // Also create a direct user notification for John
    console.log('\n📬 Creating direct user notification...');
    
    const userNotificationRef = db.collection('userNotifications')
      .doc(userId)
      .collection('notifications')
      .doc();
    
    const userNotificationData = {
      userId: userId,
      orgId: orgId,
      type: 'daily_summary',
      title: 'Manual Test Daily Summary - Sept 24, 2025 (Direct)',
      message: '🧪 This is a DIRECT user notification created during debugging.\n\n📊 Test Purpose:\n• Verify user notification collection works\n• Check if notifications appear in app inbox\n• Debug the daily summary delivery system\n\n📱 If you see this, direct user notifications work!',
      readBy: [],
      archivedBy: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetType: 'user',
      targetId: userId,
      outboxId: outboxRef.id,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    };
    
    await userNotificationRef.set(userNotificationData);
    console.log(`   ✅ Created direct user notification with ID: ${userNotificationRef.id}`);
    
    console.log('\n🎯 Next Steps:');
    console.log('   1. Check the Firebase Console Firestore to see if notifications were created');
    console.log('   2. Check the Cloud Function logs for onNotificationOutboxCreated execution');
    console.log('   3. Check the app to see if notifications appear in John\'s inbox');
    console.log('   4. If outbox works but direct doesn\'t, there\'s an app-side filtering issue');
    console.log('   5. If neither work, there\'s a deeper system issue');
    
    // Wait a moment then check if the user notification was created
    console.log('\n⏱️  Waiting 3 seconds then verifying notification was created...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    const verifyDoc = await userNotificationRef.get();
    if (verifyDoc.exists) {
      console.log('   ✅ Direct user notification confirmed in Firestore');
      const data = verifyDoc.data();
      console.log(`      Title: ${data.title}`);
      console.log(`      Created: ${data.createdAt?.toDate()}`);
    } else {
      console.log('   ❌ Direct user notification NOT found in Firestore');
    }
    
  } catch (error) {
    console.error('❌ Error during manual trigger:', error);
  }
}

manualTriggerDailySummary().then(() => {
  console.log('\n✅ Manual daily summary trigger completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Manual trigger failed:', error);
  process.exit(1);
});