// Run this in Firebase console or as a cloud function to fix existing shifts
// This will add locationIds to all shifts that don't have them

const admin = require('firebase-admin');

async function fixShiftsWithLocations() {
  const db = admin.firestore();
  
  try {
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      console.log(`Processing organization: ${orgId}`);
      
      // Get all locations for this organization
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .where('isActive', '==', true)
        .get();
      
      const locationIds = locationsSnapshot.docs.map(doc => doc.id);
      console.log(`Found ${locationIds.length} locations for org ${orgId}`);
      
      if (locationIds.length === 0) {
        console.log(`No locations found for org ${orgId}, skipping...`);
        continue;
      }
      
      // Get all shifts for this organization
      const shiftsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('shifts')
        .get();
      
      console.log(`Found ${shiftsSnapshot.docs.length} shifts for org ${orgId}`);
      
      // Update shifts that don't have locationIds
      for (const shiftDoc of shiftsSnapshot.docs) {
        const shiftData = shiftDoc.data();
        const currentLocationIds = shiftData.locationIds || [];
        
        if (currentLocationIds.length === 0) {
          console.log(`Updating shift ${shiftDoc.id} with locationIds: ${locationIds}`);
          
          await shiftDoc.ref.update({
            locationIds: locationIds,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        } else {
          console.log(`Shift ${shiftDoc.id} already has locationIds: ${currentLocationIds}`);
        }
      }
    }
    
    console.log('Finished updating shifts with locationIds');
  } catch (error) {
    console.error('Error updating shifts:', error);
  }
}

// Call the function
fixShiftsWithLocations();
