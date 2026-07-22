const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

async function testNotificationOutbox() {
  try {
    console.log('🔔 Testing notification outbox...');
    
    // Use your actual org ID from the recent signup
    const orgId = 'II9B1k7dQcHpzDoU1e9C'; // From the logs
    const locationId = 'test-location-id'; // Replace with actual location ID if you have one
    
    // Connect to the correct database - planwithhands (not default)
    const db = admin.firestore();
    const planwithhandsDb = admin.app().firestore('planwithhands');
    
    // Test 1: Send a notification to all users in organization
    console.log('📤 Creating test notification for all users...');
    await planwithhandsDb.collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add({
        title: 'Push Notification Test - All Users',
        message: 'This is a test to see if push notifications are working!',
        targetType: 'all_users',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'test'
      });
    
    console.log('✅ Test notification sent to outbox for all users');
    
    // Test 2: Send a location-specific notification (if you have location data)
    console.log('📤 Creating test notification for specific location...');
    await planwithhandsDb.collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add({
        title: 'Push Notification Test - Location',
        message: 'This is a location-specific test notification!',
        targetType: 'location',
        targetId: locationId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'test'
      });
    
    console.log('✅ Test notification sent to outbox for location');
    console.log('🔍 Check Firebase Functions logs for processing activity');
    console.log('📱 Check your device for push notifications');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

testNotificationOutbox();
