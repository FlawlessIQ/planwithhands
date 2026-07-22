const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function listOrgLocations() {
  try {
    console.log('🔍 Listing all locations in organization...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    const locationsSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    if (locationsSnapshot.empty) {
      console.log('❌ No locations found for organization!');
      return;
    }
    
    console.log(`📋 Found ${locationsSnapshot.size} locations:\n`);
    
    locationsSnapshot.forEach((doc, index) => {
      const data = doc.data();
      
      console.log(`${index + 1}. Location: "${data.name || 'Unnamed'}"`);
      console.log(`   ID: ${doc.id}`);
      console.log(`   Address: ${data.address || 'N/A'}`);
      console.log(`   Active: ${data.isActive !== false}`);
      console.log('');
    });
    
    // Look for Chickies specifically
    const chickiesLocation = locationsSnapshot.docs.find(doc => 
      doc.data().name?.toLowerCase().includes('chickies') ||
      doc.data().name?.toLowerCase().includes("chickie's")
    );
    
    if (chickiesLocation) {
      console.log(`🎯 CHICKIES LOCATION FOUND:`);
      console.log(`   Name: "${chickiesLocation.data().name}"`);
      console.log(`   ID: ${chickiesLocation.id}`);
      
      const locationId = chickiesLocation.id;
      
      // Now check shifts for this location
      console.log(`\n🔍 Checking shifts for Chickies...`);
      
      const shiftsSnapshot = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('shifts')
        .get();
      
      if (shiftsSnapshot.empty) {
        console.log('❌ No shifts found for Chickies location!');
      } else {
        console.log(`📋 Found ${shiftsSnapshot.size} shifts for Chickies:\n`);
        
        shiftsSnapshot.forEach((doc, index) => {
          const data = doc.data();
          const assignedTemplates = data.assignedTemplates || [];
          
          console.log(`${index + 1}. Shift: "${data.name || 'Unnamed'}"`);
          console.log(`   ID: ${doc.id}`);
          console.log(`   Start Time: ${data.startTime || 'N/A'}`);
          console.log(`   End Time: ${data.endTime || 'N/A'}`);
          console.log(`   Days: ${JSON.stringify(data.days || [])}`);
          console.log(`   Repeats Daily: ${data.repeatsDaily || false}`);
          console.log(`   Assigned Templates: ${assignedTemplates.length}`);
          console.log(`   Active: ${data.isActive !== false}`);
          console.log('');
        });
      }
      
    } else {
      console.log('❌ Chickies location not found!');
    }
    
  } catch (error) {
    console.error('Error listing locations:', error);
  }
}

listOrgLocations();