// Backfill missing jobTypes on daily_checklists from their templates
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();
db.settings({
  databaseId: 'planwithhands'
});

async function main() {
  console.log('🔧 Backfilling JobTypes on Daily Checklists');
  console.log('Organization: 3qjYzHagWmfbnMieJ1aj');
  console.log('═'.repeat(80));

  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  // First, get all templates and their jobTypes
  console.log('\n📋 Loading templates...');
  const templatesSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('checklist_templates')
    .get();
  
  const templateJobTypes = {};
  for (const tmpl of templatesSnap.docs) {
    const data = tmpl.data();
    const jobTypes = data.jobTypes || data.jobType;
    templateJobTypes[tmpl.id] = jobTypes;
    console.log(`  ${data.name}: ${jobTypes ? JSON.stringify(jobTypes) : '(none)'}`);
  }

  // Get all locations
  const locationsSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .get();
  
  console.log(`\n🏢 Processing ${locationsSnap.size} locations...`);
  
  let totalProcessed = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;

  for (const loc of locationsSnap.docs) {
    console.log(`\n  Location: ${loc.data().locationName} (${loc.id})`);
    
    // Get all checklists for this location
    const checklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(loc.id)
      .collection('daily_checklists')
      .get();
    
    console.log(`    Found ${checklistsSnap.size} checklists`);
    
    const batch = db.batch();
    let batchCount = 0;
    
    for (const checklist of checklistsSnap.docs) {
      totalProcessed++;
      const data = checklist.data();
      const currentJobTypes = data.jobTypes || data.jobType;
      const templateId = data.checklistTemplateId;
      
      // Skip if already has jobTypes
      if (currentJobTypes && (Array.isArray(currentJobTypes) ? currentJobTypes.length > 0 : true)) {
        totalSkipped++;
        continue;
      }
      
      // Skip if no template ID
      if (!templateId) {
        console.log(`      ⚠️  Checklist ${checklist.id} has no templateId, skipping`);
        totalSkipped++;
        continue;
      }
      
      // Get jobTypes from template
      const templateJT = templateJobTypes[templateId];
      if (!templateJT || (Array.isArray(templateJT) && templateJT.length === 0)) {
        console.log(`      ⚠️  Template ${templateId} has no jobTypes, skipping checklist ${checklist.id}`);
        totalSkipped++;
        continue;
      }
      
      // Update the checklist
      batch.update(checklist.ref, {
        jobTypes: templateJT,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      batchCount++;
      totalUpdated++;
      
      console.log(`      ✅ Will update ${data.date} - ${data.templateName}: ${JSON.stringify(templateJT)}`);
      
      // Commit batch every 450 operations (Firestore limit is 500)
      if (batchCount >= 450) {
        console.log(`      💾 Committing batch of ${batchCount} updates...`);
        await batch.commit();
        batchCount = 0;
      }
    }
    
    // Commit any remaining updates
    if (batchCount > 0) {
      console.log(`      💾 Committing final batch of ${batchCount} updates...`);
      await batch.commit();
    }
  }

  console.log('\n' + '═'.repeat(80));
  console.log('📊 Summary:');
  console.log(`  Total checklists processed: ${totalProcessed}`);
  console.log(`  Updated with jobTypes: ${totalUpdated}`);
  console.log(`  Skipped (already had jobTypes or no template): ${totalSkipped}`);
  console.log('═'.repeat(80));
  console.log('\n✅ Backfill complete! Staff users should now see missed tasks.');
  
  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
