const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

// Explicitly get the planwithhands database
const planWithHandsDb = admin.firestore();
planWithHandsDb.settings({ databaseId: 'planwithhands' });

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function deleteClosingCopyChecklist() {
  try {
    console.log('=== Deleting "(Chickies) CLOSING (Copy)" Orphaned Checklist ===');
    console.log('Database: planwithhands\n');

    // Get Chickies location
    const locationsSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .get();

    let chickiesLocationId = null;
    for (const locDoc of locationsSnapshot.docs) {
      const locData = locDoc.data();
      if (locData.name === 'Chickies') {
        chickiesLocationId = locDoc.id;
        console.log(`Found Chickies location: ${chickiesLocationId}\n`);
        break;
      }
    }

    if (!chickiesLocationId) {
      console.log('Chickies location not found!');
      return;
    }

    // Get yesterday's checklists
    const checklistsSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .where('date', '>=', admin.firestore.Timestamp.fromDate(new Date('2025-10-11')))
      .where('date', '<', admin.firestore.Timestamp.fromDate(new Date('2025-10-12')))
      .get();

    console.log(`Found ${checklistsSnapshot.size} checklists from Oct 11\n`);

    // Find the CLOSING (Copy) checklist
    let closingCopyChecklist = null;
    let closingCopyDoc = null;
    for (const checklistDoc of checklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      console.log(`  - ${checklistData.checklistName} (Shift: ${checklistData.shiftId})`);
      if (checklistData.checklistName && checklistData.checklistName.includes('CLOSING') && checklistData.checklistName.includes('Copy')) {
        closingCopyChecklist = checklistData;
        closingCopyDoc = checklistDoc;
      }
    }

    if (!closingCopyChecklist) {
      console.log('\n⚠️  CLOSING (Copy) checklist not found');
      console.log('   Trying to find it without date filter...\n');
      
      // Try without date filter
      const allChecklistsSnapshot = await planWithHandsDb
        .collection('organizations')
        .doc(ORG_ID)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .get();
      
      console.log(`Total checklists in Chickies: ${allChecklistsSnapshot.size}\n`);
      
      for (const checklistDoc of allChecklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        if (checklistData.checklistName && checklistData.checklistName.includes('CLOSING') && checklistData.checklistName.includes('Copy')) {
          closingCopyChecklist = checklistData;
          closingCopyDoc = checklistDoc;
          const dateStr = checklistData.date ? checklistData.date.toDate().toISOString().split('T')[0] : 'unknown';
          console.log(`Found it! Date: ${dateStr}`);
          break;
        }
      }
      
      if (!closingCopyChecklist) {
        console.log('⚠️  Checklist not found anywhere - may already be deleted');
        return;
      }
    }

    const dateStr = closingCopyChecklist.date ? closingCopyChecklist.date.toDate().toISOString().split('T')[0] : 'unknown';
    
    console.log('\n📋 Found checklist to delete:');
    console.log(`   ID: ${closingCopyDoc.id}`);
    console.log(`   Name: ${closingCopyChecklist.checklistName}`);
    console.log(`   Date: ${dateStr}`);
    console.log(`   Shift ID: ${closingCopyChecklist.shiftId}`);
    console.log(`   Tasks: ${closingCopyChecklist.totalItems}\n`);

    // Verify shift doesn't exist
    const shiftDoc = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('shifts')
      .doc(closingCopyChecklist.shiftId)
      .get();

    if (shiftDoc.exists) {
      console.log('⚠️  WARNING: Shift document EXISTS - not deleting!');
      console.log('   This may not be an orphaned checklist.');
      const shiftData = shiftDoc.data();
      console.log(`   Shift name: ${shiftData.name}`);
      return;
    }

    console.log('✓ Verified: Shift document does not exist (orphaned checklist)\n');

    // Count tasks in subcollection
    const tasksSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .doc(closingCopyDoc.id)
      .collection('tasks')
      .get();

    console.log(`🗑️  Deleting ${tasksSnapshot.size} tasks from subcollection...`);

    // Delete tasks in batches
    const batchSize = 500;
    let deletedTasks = 0;
    
    for (let i = 0; i < tasksSnapshot.docs.length; i += batchSize) {
      const batch = planWithHandsDb.batch();
      const batchDocs = tasksSnapshot.docs.slice(i, i + batchSize);
      
      batchDocs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      deletedTasks += batchDocs.length;
      console.log(`   Deleted ${deletedTasks} / ${tasksSnapshot.size} tasks`);
    }

    // Delete the checklist document itself
    console.log('\n🗑️  Deleting checklist document...');
    await closingCopyDoc.ref.delete();

    console.log('\n✅ DELETION COMPLETE');
    console.log(`   Deleted 1 checklist with ${tasksSnapshot.size} tasks`);
    console.log('\n💡 Refresh the app - this orphaned checklist should now be removed from "Missed Tasks from Yesterday"');

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

deleteClosingCopyChecklist();
