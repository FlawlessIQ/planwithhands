const admin = require('firebase-admin');

// Use default project config
if (!admin.apps.length) {
  admin.initializeApp();
}

// Use planwithhands database (same as Flutter app)
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function manualSyncTemplateNames() {
  console.log('🔄 Manually syncing template names for organization 3qjYzHagWmfbnMieJ1aj...');
  
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  try {
    // Get all templates for this org
    const templatesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .get();

    console.log(`📋 Found ${templatesSnapshot.docs.length} templates`);
    
    // Create a map of template ID to name
    const templateMap = new Map();
    templatesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      templateMap.set(doc.id, data.name);
      console.log(`  - ${doc.id}: "${data.name}"`);
    });

    // Get all locations for this org  
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();

    let totalUpdated = 0;
    
    // Update daily checklists in each location
    for (const locationDoc of locationsSnapshot.docs) {
      const locationId = locationDoc.id;
      console.log(`\n📍 Processing location: ${locationId}`);
      
      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .get();
      
      if (checklistsSnapshot.empty) {
        console.log('  No daily checklists found');
        continue;
      }
      
      let batch = db.batch();
      let batchCount = 0;
      let locationUpdated = 0;
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const data = checklistDoc.data();
        const templateId = data.checklistTemplateId;
        const currentName = data.templateName;
        const actualName = templateMap.get(templateId);
        
        // Update if template exists and name is different
        if (actualName && currentName !== actualName) {
          console.log(`  🔄 Updating "${currentName}" → "${actualName}"`);
          
          batch.update(checklistDoc.ref, { templateName: actualName });
          batchCount++;
          locationUpdated++;
          
          // Commit batch when it reaches 500 operations
          if (batchCount >= 500) {
            await batch.commit();
            console.log(`  💾 Committed batch of ${batchCount} updates`);
            batch = db.batch();
            batchCount = 0;
          }
        }
      }
      
      // Commit any remaining operations
      if (batchCount > 0) {
        await batch.commit();
        console.log(`  💾 Committed final batch of ${batchCount} updates`);
      }
      
      console.log(`  📊 Location ${locationId}: Updated ${locationUpdated} checklists`);
      totalUpdated += locationUpdated;
    }
    
    console.log(`\n✅ Manual sync complete! Updated ${totalUpdated} total checklists`);
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit(0);
}

manualSyncTemplateNames();