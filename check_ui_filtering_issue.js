const { getDB, admin } = require('./firebase_config');

const db = getDB();

async function checkUIFilteringIssue() {
  console.log('🔍 Investigating UI filtering issue...');
  console.log('='.repeat(60));

  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // Get the specific template from the screenshot
    const templateId = 'GRK7wpSsAHS2z66WFGMz'; // "C Server - Pre DInner"
    
    console.log('\n🎯 SPECIFIC TEMPLATE ANALYSIS:');
    const templateDoc = await db.collection('organizations').doc(orgId)
      .collection('checklist_templates').doc(templateId).get();
    
    if (templateDoc.exists) {
      const templateData = templateDoc.data();
      console.log(`Template: "${templateData.name}"`);
      console.log(`ID: ${templateId}`);
      console.log(`Location IDs: [${templateData.locationIds?.join(', ') || 'NONE'}]`);
      
      // Get location names
      const locationIds = templateData.locationIds || [];
      for (const locId of locationIds) {
        const locDoc = await db.collection('organizations').doc(orgId)
          .collection('locations').doc(locId).get();
        if (locDoc.exists) {
          const locData = locDoc.data();
          console.log(`  → Location: "${locData.name}" (${locId})`);
        } else {
          console.log(`  → Location: NOT FOUND (${locId})`);
        }
      }
    }

    // Check if there's a pagination or filtering issue
    console.log('\n📊 TEMPLATE COLLECTION ANALYSIS:');
    
    // Get all templates and see if there are duplicate names or IDs
    const allTemplatesSnapshot = await db.collection('organizations').doc(orgId)
      .collection('checklist_templates').get();
    
    console.log(`Total templates in collection: ${allTemplatesSnapshot.size}`);
    
    // Look for duplicate names
    const templatesByName = {};
    const templatesById = {};
    
    allTemplatesSnapshot.forEach(doc => {
      const data = doc.data();
      const name = data.name || 'NO NAME';
      
      // Track by name
      if (!templatesByName[name]) {
        templatesByName[name] = [];
      }
      templatesByName[name].push({
        id: doc.id,
        data: data
      });
      
      // Track by ID
      templatesById[doc.id] = {
        name: name,
        data: data
      };
    });

    // Check for duplicates
    console.log('\n🔍 DUPLICATE NAME ANALYSIS:');
    let duplicatesFound = false;
    Object.keys(templatesByName).forEach(name => {
      if (templatesByName[name].length > 1) {
        duplicatesFound = true;
        console.log(`❌ DUPLICATE NAME: "${name}" appears ${templatesByName[name].length} times:`);
        templatesByName[name].forEach(template => {
          const locationIds = template.data.locationIds || [];
          console.log(`    ID: ${template.id} → Locations: [${locationIds.join(', ')}]`);
        });
      }
    });
    
    if (!duplicatesFound) {
      console.log('✅ No duplicate template names found');
    }

    // Check if the UI might be loading from a different source
    console.log('\n🔍 POTENTIAL UI DATA SOURCES:');
    
    // Check different potential collections where templates might be stored
    const potentialCollections = [
      `organizations/${orgId}/checklist_templates`,
      `organizations/${orgId}/templates`,
      `organizations/${orgId}/checklists`,
      `checklist_templates`,
      `templates`
    ];
    
    for (const collectionPath of potentialCollections) {
      try {
        const snapshot = await db.collection(collectionPath).get();
        if (snapshot.size > 0) {
          console.log(`  📁 ${collectionPath}: ${snapshot.size} documents`);
          
          // Check if our specific template exists here
          const specificDoc = await db.collection(collectionPath).doc(templateId).get();
          if (specificDoc.exists) {
            console.log(`    🎯 Template ${templateId} found here!`);
            const data = specificDoc.data();
            console.log(`       Name: "${data.name}"`);
            console.log(`       Location IDs: [${data.locationIds?.join(', ') || 'NONE'}]`);
          }
        }
      } catch (error) {
        // Collection doesn't exist, which is fine
      }
    }

    // Check if there are any cached/today collections that might be showing old data
    console.log('\n📅 CHECKING TODAY\'S COLLECTIONS:');
    const today = new Date().toISOString().split('T')[0];
    const todayCollections = [
      `organizations/${orgId}/today`,
      `organizations/${orgId}/todayChecklists`,
      `organizations/${orgId}/dailyChecklists/${today}/checklists`
    ];
    
    for (const collectionPath of todayCollections) {
      try {
        const snapshot = await db.collection(collectionPath).get();
        if (snapshot.size > 0) {
          console.log(`  📅 ${collectionPath}: ${snapshot.size} documents`);
          
          // Look for any checklists that might reference our template
          snapshot.forEach(doc => {
            const data = doc.data();
            if (data.templateId === templateId || data.checklistTemplateId === templateId) {
              console.log(`    🎯 Found checklist using template ${templateId}:`);
              console.log(`       Checklist: "${data.name}"`);
              console.log(`       Location IDs: [${data.locationIds?.join(', ') || 'NONE'}]`);
              console.log(`       Assigned Shift: ${data.assignedShiftId || 'NONE'}`);
            }
          });
        }
      } catch (error) {
        // Collection doesn't exist
      }
    }

  } catch (error) {
    console.error('❌ Investigation failed:', error);
  }
}

checkUIFilteringIssue();