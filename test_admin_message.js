const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands'
});

const db = admin.firestore();

async function testAdminMessage() {
  console.log('🧪 TESTING NEW ADMIN MESSAGE SYSTEM');
  console.log('===================================\n');

  try {
    // Get a test organization (replace with actual org ID)
    const orgsSnapshot = await db.collection('organizations').limit(1).get();
    if (orgsSnapshot.empty) {
      console.log('❌ No organizations found');
      return;
    }

    const orgId = orgsSnapshot.docs[0].id;
    console.log('✅ Using organization:', orgId);

    // Create a test admin message notification
    const notificationRef = db.collection('organizations').doc(orgId).collection('notifications').doc();

    await notificationRef.set({
      title: 'Test Admin',
      message: 'This is a test admin message using the new onGeneralNotificationCreated system. It should send push notifications to all users in the organization.',
      targetType: 'all',
      targetId: null,
      type: 'general',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      senderId: 'test_admin_123',
      senderName: 'Test Admin',
      expiresAt: new Date(Date.now() + (30 * 24 * 60 * 60 * 1000)), // 30 days
    });

    console.log('✅ Admin message notification created with ID:', notificationRef.id);
    console.log('🔔 onGeneralNotificationCreated function should trigger now...');

    // Wait for function processing
    console.log('⏳ Waiting 10 seconds for function processing...');
    await new Promise(resolve => setTimeout(resolve, 10000));

    console.log('\n📝 Check Firebase Console Functions logs for:');
    console.log('   - onGeneralNotificationCreated processing');
    console.log('   - FCM token retrieval');
    console.log('   - Push notification sending');
    console.log('   - Success/failure counts');

  } catch (error) {
    console.error('❌ Error creating admin message:', error);
  }
}

testAdminMessage().then(() => {
  console.log('\n✅ Test completed!');
  process.exit(0);
}).catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
