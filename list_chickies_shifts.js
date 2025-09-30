const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function listChickiesShifts() {
  try {
    console.log('🔍 Listing all shifts for Chickies location...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = 'abTp8sjidL5QVirAewe6';
    
    const shiftsSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('shifts')
      .get();
    
    if (shiftsSnapshot.empty) {
      console.log('❌ No shifts found for Chickies location!');
      return;
    }
    
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
      
      if (assignedTemplates.length > 0) {
        console.log(`   Template IDs: ${assignedTemplates.join(', ')}`);
      }
      
      console.log(`   Active: ${data.isActive !== false}`);
      console.log('');
    });
    
    // Look for Pre Dinner specifically
    const preDinnerShifts = shiftsSnapshot.docs.filter(doc => 
      doc.data().name?.toLowerCase().includes('pre dinner') ||
      doc.data().name?.toLowerCase().includes('predinner')
    );
    
    if (preDinnerShifts.length > 0) {
      console.log(`🎯 PRE DINNER SHIFTS FOUND (${preDinnerShifts.length}):`);
      preDinnerShifts.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\n   ${index + 1}. "${data.name}" (ID: ${doc.id})`);
        console.log(`      Templates: ${(data.assignedTemplates || []).length}`);
      });
    } else {
      console.log('❌ No Pre Dinner shifts found!');
    }
    
  } catch (error) {
    console.error('Error listing shifts:', error);
  }
}

listChickiesShifts();