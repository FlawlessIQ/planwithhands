const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands'
});

const db = admin.firestore();

async function testAdminMessageWithLocation() {
  console.log('🧪 TESTING ADMIN MESSAGE WITH LOCATION TARGET');
  console.log('============================================\n');

  try {
    // Get a test organization
    const orgsSnapshot = await db.collection('organizations').limit(1).get();
    if (orgsSnapshot.empty) {
      console.log('❌ No organizations found');
      return;
    }

    const orgId = orgsSnapshot.docs[0].id;
    console.log('✅ Using organization:', orgId);

    // Get a location from the organization
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').limit(1).get();
    
    let targetType = 'all';
    let targetId = null;
    
    if (!locationsSnapshot.empty) {
      targetType = 'location';
      targetId = locationsSnapshot.docs[0].id;
      console.log('✅ Using location target:', targetId);
    } else {
      console.log('✅ Using "all users" target (no locations found)');
    }

    // Create a test admin message notification
    const notificationRef = db.collection('organizations').doc(orgId).collection('notifications').doc();

    const notificationData = {
      title: 'Test Admin Message',
      message: 'This is a test admin message to ' + (targetType === 'all' ? 'all users' : `location ${targetId}`),
      targetType: targetType,
      type: 'general',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      senderId: 'test_admin_123',
      senderName: 'Test Admin',
      expiresAt: new Date(Date.now() + (30 * 24 * 60 * 60 * 1000)), // 30 days
    };

    // Only add targetId if it's not null
    if (targetId) {
      notificationData.targetId = targetId;
    }

    await notificationRef.set(notificationData);

    console.log('✅ Admin message notification created with ID:', notificationRef.id);
    console.log('🔔 onGeneralNotificationCreated function should trigger now...');

    // Wait for function processing
    console.log('⏳ Waiting 15 seconds for function processing...');
    await new Promise(resolve => setTimeout(resolve, 15000));

    console.log('\n📝 Check Firebase Console Functions logs for recent execution');

  } catch (error) {
    console.error('❌ Error creating admin message:', error);
  }
}

testAdminMessageWithLocation().then(() => {
  console.log('\n✅ Test completed!');
  process.exit(0);
}).catch(error => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
