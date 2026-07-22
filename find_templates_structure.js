const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function findTemplatesStructure() {
  try {
    console.log('🔍 Finding where templates are actually stored...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
    
    // Check if templates are at organization level
    console.log('1. Checking organization-level templates...\n');
    
    const orgTemplatesSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('templates')
      .get();
    
    if (!orgTemplatesSnapshot.empty) {
      console.log(`✅ Found ${orgTemplatesSnapshot.size} templates at organization level!`);
      
      const chickiesTemplates = [];
      
      orgTemplatesSnapshot.forEach((doc) => {
        const data = doc.data();
        const templateName = data.name || 'Unnamed';
        
        console.log(`\n- ${templateName} (${doc.id})`);
        console.log(`  Location ID: ${data.locationId || 'N/A'}`);
        console.log(`  Job Types: ${JSON.stringify(data.jobTypes || [])}`);
        
        // Check if this is for Chickies
        if (data.locationId === chickiesLocationId) {
          chickiesTemplates.push({
            id: doc.id,
            name: templateName,
            jobTypes: data.jobTypes || []
          });
          console.log(`  🎯 This is a Chickies template!`);
        }
        
        // Check if this looks like a Pre Dinner template
        if (templateName.toLowerCase().includes('pre dinner')) {
          console.log(`  🎯 This is a Pre Dinner template!`);
        }
      });
      
      console.log(`\n📊 Summary: Found ${chickiesTemplates.length} templates for Chickies at org level`);
      
      if (chickiesTemplates.length > 0) {
        console.log('\n🎯 CHICKIES TEMPLATES:');
        chickiesTemplates.forEach((template, index) => {
          console.log(`${index + 1}. ${template.name} (${template.id})`);
          console.log(`   Job Types: ${JSON.stringify(template.jobTypes)}`);
        });
        
        // Look specifically for Pre Dinner ones
        const preDinnerTemplates = chickiesTemplates.filter(t => 
          t.name.toLowerCase().includes('pre dinner')
        );
        
        console.log(`\n🎯 PRE DINNER TEMPLATES: ${preDinnerTemplates.length}`);
        preDinnerTemplates.forEach((template, index) => {
          console.log(`${index + 1}. ${template.name} (${template.id})`);
        });
        
        // Look for the specific missing ones
        const hasBarPreDinner = preDinnerTemplates.some(t => 
          t.name.toLowerCase().includes('bar')
        );
        const hasServerPreDinner = preDinnerTemplates.some(t => 
          t.name.toLowerCase().includes('server')
        );
        
        console.log(`\n📋 Template Analysis:`);
        console.log(`- C Bar - Pre Dinner template exists: ${hasBarPreDinner ? '✅' : '❌'}`);
        console.log(`- C Server - Pre Dinner template exists: ${hasServerPreDinner ? '✅' : '❌'}`);
        
        if (!hasBarPreDinner || !hasServerPreDinner) {
          console.log('\n⚠️  Missing templates need to be created!');
        }
      }
      
    } else {
      console.log('❌ No templates at organization level');
    }
    
    // Use collection group query to find templates anywhere
    console.log('\n2. Using collection group query to find templates anywhere...\n');
    
    try {
      const allTemplatesSnapshot = await db.collectionGroup('templates')
        .where('locationId', '==', chickiesLocationId)
        .limit(20)
        .get();
      
      if (!allTemplatesSnapshot.empty) {
        console.log(`✅ Found ${allTemplatesSnapshot.size} Chickies templates using collection group query!`);
        
        allTemplatesSnapshot.forEach((doc, index) => {
          const data = doc.data();
          console.log(`\n${index + 1}. ${data.name || 'Unnamed'}`);
          console.log(`   ID: ${doc.id}`);
          console.log(`   Path: ${doc.ref.path}`);
          console.log(`   Job Types: ${JSON.stringify(data.jobTypes || [])}`);
        });
      } else {
        console.log('❌ No Chickies templates found with collection group query');
      }
    } catch (error) {
      console.log('❌ Collection group query failed');
    }
    
  } catch (error) {
    console.error('Error finding templates structure:', error);
  }
}

findTemplatesStructure();