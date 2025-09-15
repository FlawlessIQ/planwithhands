// Quick fix for location assignment
// Run with: node quick_location_fix.js

const admin = require('firebase-admin');

// You'll need to initialize Firebase Admin SDK with your service account
// For now, this shows the operations needed

async function fixLocationAssignment() {
  try {
    const userId = 'ah9OSUi87LhFTkewui8gZVM3ijC2'; // Your user ID from logs
    const locationId = 'hdd17KJo1LfDuJVouWmo'; // "test pub" location
    const orgId = 'UnfSxn25GWnbrrahhGRa'; // Your org ID from logs
    
    console.log('🔍 Updating user location assignment...');
    
    // Update user document
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        locationIds: [locationId],
        locationId: locationId
      });
    
    console.log('✅ User assigned to location:', locationId);
    
    // Send test notification
    await admin.firestore()
      .collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add({
        title: 'Test Location Notification',
        message: 'Testing location fix - this should now work!',
        targetType: 'location',
        targetId: locationId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [],
        archivedBy: []
      });
    
    console.log('📤 Test notification sent to location:', locationId);
    console.log('🔍 Check your notifications inbox - it should appear now!');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Uncomment to run (after setting up Firebase Admin)
// fixLocationAssignment();

console.log('Location fix script created. To use:');
console.log('1. Set up Firebase Admin SDK with service account');
console.log('2. Uncomment the fixLocationAssignment() call');
console.log('3. Run: node quick_location_fix.js');
