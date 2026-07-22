const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

async function main() {
  try {
    const userId = 'ah9OSUi87LhFTkewui8gZVM3ijC2';
    const locationId = 'hdd17KJo1LfDuJVouWmo'; // test pub
    const orgId = 'UnfSxn25GWnbrrahhGRa';
    
    console.log('📍 Assigning user to location...');
    
    // Update user document
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        locationIds: [locationId],
        locationId: locationId
      });
    
    console.log('✅ User assigned to location:', locationId);
    
    // Verify the update
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    const userData = userDoc.data();
    console.log('📋 Updated user data:');
    console.log('   locationIds:', userData.locationIds);
    console.log('   locationId:', userData.locationId);
    
    // Send test notification
    console.log('📤 Sending test notification...');
    
    await admin.firestore()
      .collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add({
        title: 'Location Fix Test',
        message: 'This notification should now reach your inbox since you are assigned to the location!',
        targetType: 'location',
        targetId: locationId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [],
        archivedBy: []
      });
    
    console.log('✅ Test notification created in outbox');
    console.log('🔍 Check your app notifications - it should appear now!');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();
