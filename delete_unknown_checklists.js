/**
 * Delete checklists with missing template names
 * 
 * Run with: node delete_unknown_checklists.js [execute]
 * Without "execute", it runs in DRY RUN mode
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function deleteUnknownChecklists(dryRun = true) {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const locationId = 'fW45ffBBPar5EaNodDYq';

  console.log(`\n${'='.repeat(80)}`);
  console.log(`DELETE UNKNOWN TEMPLATE CHECKLISTS - ${dryRun ? 'DRY RUN' : 'LIVE RUN'}`);
  console.log(`${'='.repeat(80)}\n`);

  try {
    // Get recent checklists
    const checklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .orderBy('createdAt', 'desc')
      .limit(100)
      .get();

    console.log(`Found ${checklistsSnap.size} recent checklists\n`);

    const toDelete = [];
    
    for (const doc of checklistsSnap.docs) {
      const data = doc.data();
      const hasName = data.templateName && data.templateName.trim() !== '';
      const hasTemplateId = data.checklistTemplateId && data.checklistTemplateId.trim() !== '';
      
      // Mark for deletion if missing template name OR has checklistTemplateIds array
      if (!hasName || !hasTemplateId || Array.isArray(data.checklistTemplateIds)) {
        toDelete.push({
          id: doc.id,
          ref: doc.ref,
          date: data.date,
          shiftId: data.shiftId,
          hasName,
          hasTemplateId,
          hasArray: Array.isArray(data.checklistTemplateIds),
          templateIds: data.checklistTemplateIds || []
        });
      }
    }

    console.log(`Checklists to delete: ${toDelete.length}\n`);

    if (toDelete.length === 0) {
      console.log('✅ No problem checklists found!\n');
      return;
    }

    for (const item of toDelete) {
      console.log(`Checklist: ${item.id}`);
      console.log(`  Date: ${item.date}`);
      console.log(`  Shift: ${item.shiftId}`);
      console.log(`  Has name: ${item.hasName}`);
      console.log(`  Has templateId: ${item.hasTemplateId}`);
      console.log(`  Has array: ${item.hasArray}`);
      if (item.hasArray) {
        console.log(`  Template IDs: ${item.templateIds.join(', ')}`);
      }
      
      if (!dryRun) {
        console.log(`  Deleting...`);
        
        // Delete tasks subcollection first
        const tasksSnap = await item.ref.collection('tasks').get();
        console.log(`    Deleting ${tasksSnap.size} tasks...`);
        
        const batch = db.batch();
        tasksSnap.docs.forEach(taskDoc => {
          batch.delete(taskDoc.ref);
        });
        
        if (tasksSnap.size > 0) {
          await batch.commit();
        }
        
        // Delete the checklist document
        await item.ref.delete();
        console.log(`  ✅ Deleted\n`);
      } else {
        console.log(`  [DRY RUN - would delete]\n`);
      }
    }

    if (dryRun) {
      console.log(`\n${'='.repeat(80)}`);
      console.log(`⚠️  DRY RUN COMPLETE - No changes made`);
      console.log(`To execute deletion, run: node delete_unknown_checklists.js execute`);
      console.log(`${'='.repeat(80)}\n`);
    } else {
      console.log(`\n${'='.repeat(80)}`);
      console.log(`✅ DELETION COMPLETE`);
      console.log(`Deleted ${toDelete.length} checklists`);
      console.log(`${'='.repeat(80)}\n`);
    }

  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
}

const dryRun = process.argv[2] !== 'execute';
deleteUnknownChecklists(dryRun)
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
