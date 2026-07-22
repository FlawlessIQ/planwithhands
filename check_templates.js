const admin = require('firebase-admin');

// Initialize Firebase Admin (use application default credentials)
admin.initializeApp({
  projectId: 'planwithhands'
});

const db = admin.firestore();

async function checkTemplates() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const locationId = 'fW45ffBBPar5EaNodDYq';
  const shiftId = 'VY0xGrIzvHSaqX1AXkcY';
  
  const templateIds = [
    'Ezuho3cKjbKv4MZR59dU',
    'H8NR6hf2KQtl9rGHsNzR',
    'cFv5sR9JZd220cjv6g3O',
    'fXYrAHM462QbGiW7sZWl'
  ];
  
  console.log('\n=== CHECKING TEMPLATES FROM CHECKLIST ===\n');
  
  for (const templateId of templateIds) {
    try {
      const templateDoc = await db
        .collection('organizations')
        .doc(orgId)
        .collection('checklist_templates')
        .doc(templateId)
        .get();
      
      if (templateDoc.exists) {
        const data = templateDoc.data();
        console.log(`✅ Template ${templateId}:`);
        console.log(`   Name: ${data.name || '(NO NAME)'}`);
        console.log(`   Location IDs: ${JSON.stringify(data.locationIds || data.locationId)}`);
        console.log(`   Active: ${data.active}`);
        console.log(`   Deleted: ${data.deleted}`);
      } else {
        console.log(`❌ Template ${templateId}: NOT FOUND`);
      }
    } catch (error) {
      console.error(`Error checking template ${templateId}:`, error.message);
    }
  }
  
  console.log('\n=== CHECKING SHIFT CONFIGURATION ===\n');
  
  try {
    const shiftDoc = await db
      .collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .doc(shiftId)
      .get();
    
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      console.log(`✅ Shift ${shiftId}:`);
      console.log(`   Name: ${shiftData.shiftName}`);
      console.log(`   Template IDs: ${JSON.stringify(shiftData.checklistTemplateIds)}`);
      console.log(`   Location IDs: ${JSON.stringify(shiftData.locationIds || shiftData.locationId)}`);
      console.log(`   Repeats Daily: ${shiftData.repeatsDaily}`);
      console.log(`   Active Days: ${JSON.stringify(shiftData.activeDays || shiftData.days)}`);
    } else {
      console.log(`❌ Shift ${shiftId}: NOT FOUND`);
    }
  } catch (error) {
    console.error(`Error checking shift:`, error.message);
  }
  
  console.log('\n=== CHECKING ALL VALID TEMPLATES FOR THIS LOCATION ===\n');
  
  try {
    const allTemplates = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .get();
    
    console.log(`Total templates in org: ${allTemplates.docs.length}`);
    
    const validForLocation = [];
    
    for (const doc of allTemplates.docs) {
      const data = doc.data();
      const locationIds = Array.isArray(data.locationIds) 
        ? data.locationIds 
        : (data.locationId ? [data.locationId] : []);
      
      if (locationIds.includes(locationId) && data.name && !data.deleted) {
        validForLocation.push({
          id: doc.id,
          name: data.name,
          active: data.active
        });
      }
    }
    
    console.log(`\nValid templates for location ${locationId}:`);
    validForLocation.forEach(t => {
      console.log(`  - ${t.id}: ${t.name} (active: ${t.active})`);
    });
  } catch (error) {
    console.error(`Error checking all templates:`, error.message);
  }
}

checkTemplates()
  .then(() => {
    console.log('\n=== CHECK COMPLETE ===\n');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
