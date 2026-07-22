const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.fixUserLocation = functions.https.onCall(async (data, context) => {
  try {
    console.log('fixUserLocation called with data:', data);
    
    const userId = data.userId || (context.auth ? context.auth.uid : null);
    const locationId = data.locationId || 'hdd17KJo1LfDuJVouWmo'; // test pub
    const orgId = data.orgId || 'UnfSxn25GWnbrrahhGRa';
    
    if (!userId) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    console.log('Fixing location for user:', userId, 'location:', locationId);
    
    // Try multiple possible user document locations
    const possiblePaths = [
      { ref: admin.firestore().collection('users').doc(userId), name: 'users/' + userId },
      { ref: admin.firestore().collection('organizations').doc(orgId).collection('users').doc(userId), name: 'organizations/' + orgId + '/users/' + userId },
      { ref: admin.firestore().collection('organizations').doc(orgId).collection('members').doc(userId), name: 'organizations/' + orgId + '/members/' + userId }
    ];
    
    let updated = false;
    
    for (const pathInfo of possiblePaths) {
      try {
        console.log('Checking path:', pathInfo.name);
        const doc = await pathInfo.ref.get();
        if (doc.exists) {
          console.log('Found user document at:', pathInfo.name);
          console.log('Current data:', doc.data());
          
          await pathInfo.ref.update({
            locationIds: [locationId],
            locationId: locationId
          });
          
          console.log('Updated user location assignment');
          updated = true;
          break;
        } else {
          console.log('Document does not exist at:', pathInfo.name);
        }
      } catch (e) {
        console.log('Error checking path:', pathInfo.name, e.message);
      }
    }
    
    if (!updated) {
      // Try to create the user document if it doesn't exist
      console.log('User document not found, attempting to create...');
      try {
        await admin.firestore().collection('users').doc(userId).set({
          locationIds: [locationId],
          locationId: locationId,
          organizationId: orgId,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        console.log('Created/updated user document');
        updated = true;
      } catch (createError) {
        console.error('Error creating user document:', createError);
        throw new functions.https.HttpsError('internal', 'Could not find or create user document');
      }
    }
    
    // Send test notification
    console.log('Sending test notification...');
    await admin.firestore()
      .collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add({
        title: 'Location Assignment Fixed ✅',
        message: 'Your user has been assigned to a location. Location notifications should now work!',
        targetType: 'location',
        targetId: locationId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readBy: [],
        archivedBy: []
      });
    
    console.log('Test notification sent');
    
    return {
      success: true,
      message: 'User assigned to location and test notification sent',
      locationId: locationId,
      userId: userId
    };
    
  } catch (error) {
    console.error('Error fixing user location:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
