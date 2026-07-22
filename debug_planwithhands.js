const admin = require('firebase-admin');

// Use default project config
if (!admin.apps.length) {
  admin.initializeApp();
}

// Use planwithhands database (same as Flutter app)
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function debugPlanWithHandsDatabase() {
  console.log('🔍 Debugging organization 3qjYzHagWmfbnMieJ1aj in PLANWITHHANDS database...');
  
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locationIds = ['3mkG9233plgeu94IVE71', 'EazZJYpWQB8XWHw464C2', 'sYhcOTkX1VkeoPjtPuwZ'];
  
  try {
    // Get all templates for this org
    const templatesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .get();

    console.log(`📋 Found ${templatesSnapshot.docs.length} templates:`);
    const templateMap = new Map();
    templatesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      templateMap.set(doc.id, data.name);
      console.log(`  - ${doc.id}: "${data.name}"`);
    });

    // Check daily checklists in each location
    for (const locationId of locationIds) {
      console.log(`\n📍 Checking location ${locationId}:`);
      
      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .orderBy('date', 'desc')
        .limit(5)
        .get();
      
      if (checklistsSnapshot.empty) {
        console.log('  No daily checklists found');
      } else {
        console.log(`  Found ${checklistsSnapshot.docs.length} daily checklists:`);
        checklistsSnapshot.docs.forEach(doc => {
          const data = doc.data();
          const templateId = data.checklistTemplateId;
          const storedTemplateName = data.templateName;
          const actualTemplateName = templateMap.get(templateId);
          
          console.log(`  📋 ${doc.id}:`);
          console.log(`      Template ID: ${templateId}`);
          console.log(`      Stored Name: "${storedTemplateName}"`);
          console.log(`      Actual Name: "${actualTemplateName || 'TEMPLATE NOT FOUND'}"`);
          console.log(`      Date: ${data.date}`);
          console.log(`      Match: ${storedTemplateName === actualTemplateName ? '✅' : '❌'}`);
        });
      }
    }
    
    // Also check for any shifts that might reference checklists
    console.log(`\n🔄 Checking shifts:`);
    for (const locationId of locationIds) {
      console.log(`  📍 Shifts in location ${locationId}:`);
      
      const shiftsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('shifts')
        .limit(5)
        .get();
      
      if (!shiftsSnapshot.empty) {
        shiftsSnapshot.docs.forEach(doc => {
          const data = doc.data();
          console.log(`    🔄 ${doc.id}: "${data.name}" - Checklists: ${JSON.stringify(data.checklists || [])}`);
        });
      } else {
        console.log('    No shifts found');
      }
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  console.log('\n✅ Debug complete');
  process.exit(0);
}

debugPlanWithHandsDatabase();