const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

async function testWithExistingUser() {
  try {
    console.log('🔔 Testing notification with existing user...');
    
    // Use the existing user's organization
    const orgId = 'UnfSxn25GWnbrrahhGRa';
    
    // Connect to the correct database
    const db = admin.app().firestore('planwithhands');
    
    // Send a notification to all users in this organization
    console.log('📤 Creating test notification for existing user organization...');
    await db.collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add({
        title: 'Push Notification Test - Existing User',
        message: 'Testing push notifications with real user organization!',
        targetType: 'all_users',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'test'
      });
    
    console.log('✅ Test notification sent to outbox for existing user organization');
    console.log('🔍 Check Firebase Functions logs for processing activity');
    console.log('📱 If the user has FCM tokens, they should receive the notification');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

testWithExistingUser();
