const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function debugPreDinnerDaily() {
  try {
    console.log('🔍 Debugging Pre Dinner daily checklists in correct database...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = 'abTp8sjidL5QVirAewe6';
    const shiftId = 'JLo4mc11PpjK9HOdRcdV'; // From our findings
    const date = '2025-09-29';
    
    console.log(`Organization: ${orgId}`);
    console.log(`Location: ${locationId} (Chickies)`);
    console.log(`Shift: ${shiftId} (Pre Dinner)`);
    console.log(`Date: ${date}\n`);
    
    // Check if daily checklists exist at location level
    console.log('1. Checking daily checklists at location level...');
    
    const locationDailyQuery = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .where('shiftId', '==', shiftId);
    
    const locationDailySnapshot = await locationDailyQuery.get();
    
    if (locationDailySnapshot.empty) {
      console.log('❌ No daily checklists found at location level');
    } else {
      console.log(`✅ Found ${locationDailySnapshot.size} daily checklists at location level!`);
      
      locationDailySnapshot.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\n${index + 1}. ${data.templateName || 'Unnamed'}`);
        console.log(`   ID: ${doc.id}`);
        console.log(`   Template ID: ${data.templateId}`);
        console.log(`   Job Types: ${JSON.stringify(data.jobTypes || [])}`);
      });
    }
    
    // Check if daily checklists exist at organization level
    console.log('\n2. Checking daily checklists at organization level...');
    
    const orgDailyQuery = db.collection('organizations')
      .doc(orgId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .where('shiftId', '==', shiftId)
      .where('locationId', '==', locationId);
    
    const orgDailySnapshot = await orgDailyQuery.get();
    
    if (orgDailySnapshot.empty) {
      console.log('❌ No daily checklists found at organization level');
    } else {
      console.log(`✅ Found ${orgDailySnapshot.size} daily checklists at organization level!`);
      
      orgDailySnapshot.forEach((doc, index) => {
        const data = doc.data();
        console.log(`\n${index + 1}. ${data.templateName || 'Unnamed'}`);
        console.log(`   ID: ${doc.id}`);
        console.log(`   Template ID: ${data.templateId}`);
        console.log(`   Job Types: ${JSON.stringify(data.jobTypes || [])}`);
      });
    }
    
    // Use collection group query to find daily checklists anywhere
    console.log('\n3. Using collection group query to find daily checklists...');
    
    try {
      const allDailyQuery = db.collectionGroup('daily_checklists')
        .where('organizationId', '==', orgId)
        .where('locationId', '==', locationId)
        .where('date', '==', date)
        .where('shiftId', '==', shiftId);
      
      const allDailySnapshot = await allDailyQuery.get();
      
      if (allDailySnapshot.empty) {
        console.log('❌ No daily checklists found anywhere with collection group query');
      } else {
        console.log(`✅ Found ${allDailySnapshot.size} daily checklists with collection group query!`);
        
        allDailySnapshot.forEach((doc, index) => {
          const data = doc.data();
          console.log(`\n${index + 1}. ${data.templateName || 'Unnamed'}`);
          console.log(`   ID: ${doc.id}`);
          console.log(`   Path: ${doc.ref.path}`);
          console.log(`   Template ID: ${data.templateId}`);
          console.log(`   Job Types: ${JSON.stringify(data.jobTypes || [])}`);
        });
      }
    } catch (error) {
      console.log('❌ Collection group query failed (may need index)');
    }
    
    // Check what templates are assigned to the Pre Dinner shift
    console.log('\n4. Checking shift template assignments...');
    
    const shiftDoc = await db.collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .doc(shiftId)
      .get();
    
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      console.log(`\nShift: ${shiftData.name || 'Unnamed'}`);
      console.log(`Location ID: ${shiftData.locationId || 'N/A'}`);
      console.log(`Assigned Templates: ${(shiftData.assignedTemplates || []).length}`);
      
      if (shiftData.assignedTemplates && shiftData.assignedTemplates.length > 0) {
        console.log(`Template IDs: ${shiftData.assignedTemplates.join(', ')}`);
      } else {
        console.log('⚠️  No templates assigned to this shift!');
      }
    } else {
      console.log('❌ Shift document not found');
    }
    
  } catch (error) {
    console.error('Error debugging daily checklists:', error);
  }
}

debugPreDinnerDaily();