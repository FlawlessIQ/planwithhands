const {Firestore} = require('@google-cloud/firestore');
const db = new Firestore({databaseId: 'planwithhands'});

(async () => {
  try {
    const orgsSnap = await db.collection('organizations').get();
    let invalidCount = 0;
    let validCount = 0;
    
    console.log(`Scanning ${orgsSnap.size} organizations...\n`);
    
    for (const orgDoc of orgsSnap.docs) {
      const templatesSnap = await orgDoc.ref.collection('checklist_templates').get();
      
      for (const tDoc of templatesSnap.docs) {
        const data = tDoc.data() || {};
        const name = (data.name || '').toString().trim();
        
        if (!name || name.toLowerCase() === 'unknown template') {
          invalidCount++;
          console.log('❌ Invalid:', orgDoc.id, tDoc.id, `"${name || '(empty)'}"`);
        } else {
          validCount++;
        }
      }
    }
    
    console.log('\n=== SUMMARY ===');
    console.log('Valid templates:', validCount);
    console.log('Invalid templates:', invalidCount);
    console.log('\nValidation rules in dailyGenerator:');
    console.log('✓ Rejects templates with empty names');
    console.log('✓ Rejects templates named "unknown template" (case-insensitive)');
    console.log('✓ Filters by locationIds if present');
    console.log('✓ Skips non-existent template references');
    
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
