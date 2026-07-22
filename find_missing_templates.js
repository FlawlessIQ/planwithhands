const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function findMissingTemplates() {
  try {
    console.log('🔍 Looking for the missing C Bar and C Server Pre Dinner templates...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
    
    // Get ALL templates for Chickies
    const templatesSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('templates')
      .get();
    
    console.log(`Found ${templatesSnapshot.size} total templates for Chickies:\n`);
    
    const allTemplates = [];
    templatesSnapshot.forEach((doc) => {
      const data = doc.data();
      allTemplates.push({
        id: doc.id,
        name: data.name || 'Unnamed',
        jobTypes: data.jobTypes || []
      });
    });
    
    // Sort by name for easier reading
    allTemplates.sort((a, b) => a.name.localeCompare(b.name));
    
    allTemplates.forEach((template, index) => {
      console.log(`${index + 1}. ${template.name} (${template.id})`);
      console.log(`   Job Types: ${JSON.stringify(template.jobTypes)}`);
      
      // Check if this could be a Pre Dinner template
      const nameLower = template.name.toLowerCase();
      if (nameLower.includes('pre') || nameLower.includes('dinner')) {
        console.log(`   🎯 This looks like a Pre Dinner template!`);
      }
      console.log('');
    });
    
    // Look specifically for bar and server templates
    console.log('🔍 Looking for Bar and Server templates...\n');
    
    const barTemplates = allTemplates.filter(t => 
      t.name.toLowerCase().includes('bar') && 
      t.name.toLowerCase().includes('pre')
    );
    
    const serverTemplates = allTemplates.filter(t => 
      t.name.toLowerCase().includes('server') && 
      t.name.toLowerCase().includes('pre')
    );
    
    console.log(`Bar Pre Dinner templates found: ${barTemplates.length}`);
    barTemplates.forEach(t => console.log(`- ${t.name} (${t.id})`));
    
    console.log(`\nServer Pre Dinner templates found: ${serverTemplates.length}`);
    serverTemplates.forEach(t => console.log(`- ${t.name} (${t.id})`));
    
    // Check if they exist with different names
    console.log('\n🔍 Looking for templates with similar names...\n');
    
    const possibleBarTemplates = allTemplates.filter(t => 
      t.name.toLowerCase().includes('bar') || 
      t.name.toLowerCase().includes('bartender')
    );
    
    const possibleServerTemplates = allTemplates.filter(t => 
      t.name.toLowerCase().includes('server')
    );
    
    console.log(`Possible Bar templates: ${possibleBarTemplates.length}`);
    possibleBarTemplates.forEach(t => console.log(`- ${t.name} (${t.id})`));
    
    console.log(`\nPossible Server templates: ${possibleServerTemplates.length}`);
    possibleServerTemplates.forEach(t => console.log(`- ${t.name} (${t.id})`));
    
    // If we can't find them, maybe they're at a different location or named differently
    console.log('\n💡 Based on our previous findings, the missing checklists were:');
    console.log('- "C Bar - Pre Dinner" ');
    console.log('- "C Server - Pre Dinner"');
    console.log('\nThese might need to be created from existing templates or created fresh.');
    
  } catch (error) {
    console.error('Error finding templates:', error);
  }
}

findMissingTemplates();