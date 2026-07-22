const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

/**
 * Delete checklists that were incorrectly generated for days when
 * their shift was not scheduled to run
 */

async function deleteIncorrectlyScheduledChecklists() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // The Hamilton Inn
    const yesterday = '2025-10-11'; // Saturday (day index 6)
    
    console.log('🧹 Deleting incorrectly scheduled checklists...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Location: The Hamilton Inn (${locationId})`);
    console.log(`Date: ${yesterday} (Saturday - day index 6)\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Get shifts to check their schedules
    const shiftsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('shifts')
      .get();
    
    // Map day names to indices (JavaScript convention: 0=Sunday, 6=Saturday)
    const dayNameToIndex = {
      'Sunday': 0,
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
      'Saturday': 6,
    };
    
    const shiftSchedules = {};
    shiftsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const days = data.days || [];
      const repeatsDaily = data.repeatsDaily === true;
      
      // Convert day names to indices
      const dayIndices = days.map(d => dayNameToIndex[d]).filter(i => i !== undefined);
      
      shiftSchedules[doc.id] = {
        name: data.shiftName || data.name || 'Unknown',
        dayIndices,
        repeatsDaily,
        runsOnSaturday: repeatsDaily || dayIndices.includes(6),
      };
    });
    
    console.log('Shift Schedules:\n');
    Object.entries(shiftSchedules).forEach(([id, info]) => {
      const status = info.runsOnSaturday ? '✅ Runs on Saturday' : '❌ Does NOT run on Saturday';
      console.log(`  ${info.name}: ${status}`);
      if (!info.repeatsDaily) {
        console.log(`    Days: ${info.dayIndices.join(', ')}`);
      } else {
        console.log(`    Repeats daily: true`);
      }
    });
    
    console.log(`\n${'='.repeat(80)}\n`);
    
    // Get yesterday's checklists
    const checklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', yesterday)
      .get();
    
    console.log(`Found ${checklistsSnapshot.docs.length} checklists for yesterday\n`);
    
    const toDelete = [];
    let totalTasksToDelete = 0;
    
    for (const checklistDoc of checklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      const templateName = checklistData.templateName || 'Unknown';
      const shiftId = checklistData.shiftId;
      const shiftInfo = shiftSchedules[shiftId];
      
      if (!shiftInfo) {
        console.log(`⚠️  ${templateName}: Unknown shift (${shiftId}) - SKIPPING`);
        continue;
      }
      
      // Check if shift should have run on Saturday
      if (!shiftInfo.runsOnSaturday) {
        // Count tasks
        const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
        const normalTasks = tasksSnapshot.docs.filter(d => d.data().isCarryForward !== true);
        
        toDelete.push({
          id: checklistDoc.id,
          templateName,
          shiftName: shiftInfo.name,
          taskCount: normalTasks.length,
        });
        
        totalTasksToDelete += normalTasks.length;
        console.log(`❌ ${templateName} (${shiftInfo.name}): ${normalTasks.length} tasks - WILL DELETE`);
      } else {
        console.log(`✅ ${templateName} (${shiftInfo.name}): Correctly scheduled`);
      }
    }
    
    console.log(`\n${'='.repeat(80)}\n`);
    
    if (toDelete.length === 0) {
      console.log('✅ No incorrectly scheduled checklists found.\n');
      return;
    }
    
    console.log(`\n🗑️  DELETING ${toDelete.length} incorrectly scheduled checklists...\n`);
    
    for (const item of toDelete) {
      console.log(`  Deleting: ${item.templateName} (${item.shiftName})`);
      console.log(`    Checklist ID: ${item.id}`);
      
      // Delete all tasks in the checklist
      const tasksSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists').doc(item.id)
        .collection('tasks')
        .get();
      
      if (tasksSnapshot.docs.length > 0) {
        const batch = db.batch();
        tasksSnapshot.docs.forEach(taskDoc => {
          batch.delete(taskDoc.ref);
        });
        await batch.commit();
        console.log(`    ✅ Deleted ${tasksSnapshot.docs.length} tasks`);
      }
      
      // Delete the checklist document
      await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists').doc(item.id)
        .delete();
      
      console.log(`    ✅ Deleted checklist\n`);
    }
    
    console.log(`${'='.repeat(80)}\n`);
    console.log(`\n✅ DELETION COMPLETE!\n`);
    console.log(`Summary:`);
    console.log(`  - Deleted ${toDelete.length} incorrectly scheduled checklists`);
    console.log(`  - Removed ${totalTasksToDelete} tasks from "Missed Yesterday" count\n`);
    console.log(`💡 The "Missed Yesterday" count should now be ${123 - totalTasksToDelete} (down from 123).\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

deleteIncorrectlyScheduledChecklists();
