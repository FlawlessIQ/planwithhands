const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize Firebase Admin
admin.initializeApp();

async function testLocationFix() {
  try {
    const userId = 'ah9OSUi87LhFTkewui8gZVM3ijC2';
    const locationId = 'hdd17KJo1LfDuJVouWmo'; // test pub
    const orgId = 'UnfSxn25GWnbrrahhGRa';
    
    console.log('🔍 Testing location fix...');
    
    // Use the Firebase Admin SDK method your app likely uses
    const db = getFirestore();
    
    // Try to find and update the user document
    console.log('Attempting to update user document...');
    
    try {
      // Try the users collection first
      await db.collection('users').doc(userId).set({
        locationIds: [locationId],
        locationId: locationId,
        organizationId: orgId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      console.log('✅ User document updated/created in users collection');
    } catch (e) {
      console.log('❌ Error updating users collection:', e.message);
    }
    
    // Send test notification
    console.log('📤 Sending test notification...');
    
    await db.collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add({
        title: 'Location Fix Test ✅',
        message: 'This notification should now reach your inbox! User assigned to location: ' + locationId,
        targetType: 'location',
        targetId: locationId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [],
        archivedBy: []
      });
    
    console.log('✅ Test notification sent to outbox');
    console.log('🔍 Check your app notifications - it should appear now!');
    console.log('📍 Location ID used:', locationId);
    console.log('👤 User ID:', userId);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

testLocationFix();
