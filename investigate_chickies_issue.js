const { getDB, admin } = require('./firebase_config');

const db = getDB();

async function investigateChickiesIssue() {
  console.log('🔍 Deep investigation of Chickies templates issue...');
  console.log('='.repeat(60));

  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // Get all locations first
    console.log('\n📍 LOCATIONS:');
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    const locations = {};
    
    locationsSnapshot.forEach(doc => {
      const data = doc.data();
      locations[doc.id] = data;
      console.log(`  ${doc.id}: "${data.name || 'NO NAME'}" (${data.address || 'No address'})`);
    });

    // Get all templates and analyze the "C" templates specifically
    console.log('\n📋 ALL TEMPLATES:');
    const templatesSnapshot = await db.collection('organizations').doc(orgId).collection('checklist_templates').get();
    
    const chickiesTemplates = [];
    const hamiltonTemplates = [];
    const innTemplates = [];
    const uncategorizedTemplates = [];

    templatesSnapshot.forEach(doc => {
      const data = doc.data();
      const templateName = data.name || 'NO NAME';
      const locationIds = data.locationIds || [];
      
      // Categorize by template name prefix
      if (templateName.startsWith('C ')) {
        chickiesTemplates.push({
          id: doc.id,
          name: templateName,
          locationIds: locationIds,
          locationNames: locationIds.map(id => locations[id]?.name || `Unknown(${id})`).join(', ')
        });
      } else if (templateName.startsWith('H ')) {
        hamiltonTemplates.push({
          id: doc.id,
          name: templateName,
          locationIds: locationIds,
          locationNames: locationIds.map(id => locations[id]?.name || `Unknown(${id})`).join(', ')
        });
      } else if (templateName.startsWith('I ')) {
        innTemplates.push({
          id: doc.id,
          name: templateName,
          locationIds: locationIds,
          locationNames: locationIds.map(id => locations[id]?.name || `Unknown(${id})`).join(', ')
        });
      } else {
        uncategorizedTemplates.push({
          id: doc.id,
          name: templateName,
          locationIds: locationIds,
          locationNames: locationIds.map(id => locations[id]?.name || `Unknown(${id})`).join(', ')
        });
      }
    });

    console.log(`\n🐔 CHICKIES TEMPLATES (${chickiesTemplates.length}):`);
    chickiesTemplates.forEach(template => {
      const isCorrectLocation = template.locationNames.includes('Chickies');
      const status = isCorrectLocation ? '✅' : '❌';
      console.log(`  ${status} ${template.name}`);
      console.log(`      ID: ${template.id}`);
      console.log(`      Locations: ${template.locationNames || 'NONE'}`);
      console.log(`      Location IDs: [${template.locationIds.join(', ')}]`);
      console.log('');
    });

    console.log(`\n🏠 HAMILTON TEMPLATES (${hamiltonTemplates.length}):`);
    hamiltonTemplates.forEach(template => {
      const isCorrectLocation = template.locationNames.includes('Hamilton Pork');
      const status = isCorrectLocation ? '✅' : '❌';
      console.log(`  ${status} ${template.name}`);
      console.log(`      Locations: ${template.locationNames || 'NONE'}`);
      console.log('');
    });

    console.log(`\n🏨 INN TEMPLATES (${innTemplates.length}):`);
    innTemplates.forEach(template => {
      const isCorrectLocation = template.locationNames.includes('The Hamilton Inn');
      const status = isCorrectLocation ? '✅' : '❌';
      console.log(`  ${status} ${template.name}`);
      console.log(`      Locations: ${template.locationNames || 'NONE'}`);
      console.log('');
    });

    if (uncategorizedTemplates.length > 0) {
      console.log(`\n❓ UNCATEGORIZED TEMPLATES (${uncategorizedTemplates.length}):`);
      uncategorizedTemplates.forEach(template => {
        console.log(`  📋 ${template.name}`);
        console.log(`      Locations: ${template.locationNames || 'NONE'}`);
        console.log('');
      });
    }

    // Check shifts to see which templates are assigned where
    console.log('\n⏰ SHIFT TEMPLATE ASSIGNMENTS:');
    const shiftsSnapshot = await db.collection('organizations').doc(orgId).collection('shifts').get();
    
    shiftsSnapshot.forEach(doc => {
      const data = doc.data();
      const shiftName = data._shiftName || data.shiftName || 'NO NAME';
      const shiftLocationIds = data.locationIds || [];
      const shiftLocationNames = shiftLocationIds.map(id => locations[id]?.name || `Unknown(${id})`).join(', ');
      const templateIds = data.checklistTemplateIds || [];
      
      console.log(`\n  🕐 Shift: "${shiftName}"`);
      console.log(`      Location: ${shiftLocationNames}`);
      console.log(`      Templates (${templateIds.length}):`);
      
      templateIds.forEach(templateId => {
        // Find template name
        const template = [...chickiesTemplates, ...hamiltonTemplates, ...innTemplates, ...uncategorizedTemplates]
          .find(t => t.id === templateId);
        
        if (template) {
          const isMatchingLocation = template.locationNames === shiftLocationNames;
          const status = isMatchingLocation ? '✅' : '❌';
          console.log(`        ${status} ${template.name} (${template.locationNames})`);
        } else {
          console.log(`        ❓ Unknown template: ${templateId}`);
        }
      });
    });

    // Summary of issues
    console.log('\n' + '='.repeat(60));
    console.log('🚨 ISSUE SUMMARY:');
    
    const wrongChickiesTemplates = chickiesTemplates.filter(t => !t.locationNames.includes('Chickies'));
    const wrongHamiltonTemplates = hamiltonTemplates.filter(t => !t.locationNames.includes('Hamilton Pork'));
    const wrongInnTemplates = innTemplates.filter(t => !t.locationNames.includes('The Hamilton Inn'));
    
    if (wrongChickiesTemplates.length > 0) {
      console.log(`\n❌ ${wrongChickiesTemplates.length} Chickies templates NOT at Chickies location:`);
      wrongChickiesTemplates.forEach(t => {
        console.log(`  - ${t.name} → ${t.locationNames}`);
      });
    }
    
    if (wrongHamiltonTemplates.length > 0) {
      console.log(`\n❌ ${wrongHamiltonTemplates.length} Hamilton templates NOT at Hamilton location:`);
      wrongHamiltonTemplates.forEach(t => {
        console.log(`  - ${t.name} → ${t.locationNames}`);
      });
    }
    
    if (wrongInnTemplates.length > 0) {
      console.log(`\n❌ ${wrongInnTemplates.length} Inn templates NOT at Inn location:`);
      wrongInnTemplates.forEach(t => {
        console.log(`  - ${t.name} → ${t.locationNames}`);
      });
    }

    if (wrongChickiesTemplates.length === 0 && wrongHamiltonTemplates.length === 0 && wrongInnTemplates.length === 0) {
      console.log('\n✅ All templates appear to be at correct locations based on name prefixes');
    }

  } catch (error) {
    console.error('❌ Investigation failed:', error);
  }
}

investigateChickiesIssue();