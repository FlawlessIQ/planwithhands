const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function findShiftsStructure() {
  try {
    console.log('🔍 Exploring database structure to find shifts...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // Check if shifts are at organization level
    console.log('1. Checking organization-level shifts...');
    const orgShiftsSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .get();
    
    if (!orgShiftsSnapshot.empty) {
      console.log(`✅ Found ${orgShiftsSnapshot.size} shifts at organization level!`);
      
      orgShiftsSnapshot.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\n${index + 1}. Shift: "${data.name || 'Unnamed'}"`);
        console.log(`   ID: ${doc.id}`);
        console.log(`   Location: ${data.locationId || 'N/A'}`);
        console.log(`   Start Time: ${data.startTime || 'N/A'}`);
        console.log(`   End Time: ${data.endTime || 'N/A'}`);
        console.log(`   Templates: ${(data.assignedTemplates || []).length}`);
      });
      
      // Filter for Chickies location
      const chickiesShifts = orgShiftsSnapshot.docs.filter(doc => 
        doc.data().locationId === 'abTp8sjidL5QVirAewe6'
      );
      
      if (chickiesShifts.length > 0) {
        console.log(`\n🎯 CHICKIES SHIFTS (${chickiesShifts.length}):`);
        chickiesShifts.forEach((doc, index) => {
          const data = doc.data();
          console.log(`\n   ${index + 1}. "${data.name}" (ID: ${doc.id})`);
          console.log(`      Templates: ${(data.assignedTemplates || []).length}`);
          
          if (data.name?.toLowerCase().includes('pre dinner')) {
            console.log(`      🎯 This is the Pre Dinner shift!`);
          }
        });
      }
      
    } else {
      console.log('❌ No shifts at organization level');
    }
    
    // Check if shifts use a different collection name
    console.log('\n2. Checking for alternative shift collection names...');
    
    const collectionsToCheck = ['shift', 'work_shifts', 'schedules', 'schedule'];
    
    for (const collectionName of collectionsToCheck) {
      try {
        const altShiftsSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection(collectionName)
          .limit(1)
          .get();
        
        if (!altShiftsSnapshot.empty) {
          console.log(`✅ Found data in collection: ${collectionName}`);
        }
      } catch (error) {
        // Collection doesn't exist, continue
      }
    }
    
    // Use collection group query to find shifts anywhere
    console.log('\n3. Using collection group query to find shifts anywhere...');
    
    const allShiftsSnapshot = await db.collectionGroup('shifts')
      .where('organizationId', '==', orgId)
      .limit(10)
      .get();
    
    if (!allShiftsSnapshot.empty) {
      console.log(`✅ Found ${allShiftsSnapshot.size} shifts using collection group query!`);
      
      allShiftsSnapshot.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\n${index + 1}. Shift: "${data.name || 'Unnamed'}"`);
        console.log(`   ID: ${doc.id}`);
        console.log(`   Path: ${doc.ref.path}`);
        console.log(`   Location: ${data.locationId || 'N/A'}`);
        
        if (data.locationId === 'abTp8sjidL5QVirAewe6') {
          console.log(`   🎯 This is a Chickies shift!`);
        }
      });
    } else {
      console.log('❌ No shifts found with collection group query');
    }
    
  } catch (error) {
    console.error('Error exploring database structure:', error);
  }
}

findShiftsStructure();