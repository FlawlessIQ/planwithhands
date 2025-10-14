const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

/**
 * Clean up incorrectly scheduled checklists across ALL locations
 * Focuses on weekday shifts that ran on Saturday (Oct 11, 2025)
 */

async function cleanupAllIncorrectlyScheduledChecklists() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const saturday = '2025-10-11'; // Saturday
    
    console.log('🧹 Cleaning up incorrectly scheduled checklists across ALL locations...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Date: ${saturday} (Saturday - day index 6)\n`);
    console.log(`Database: planwithhands\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`Found ${locationsSnapshot.docs.length} locations\n`);
    
    // Get all shifts to check their schedules
    const shiftsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('shifts')
      .get();
    
    // Map day names to indices
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
    
    console.log('Shift Schedules Analysis:\n');
    const weekdayShifts = [];
    Object.entries(shiftSchedules).forEach(([id, info]) => {
      const status = info.runsOnSaturday ? '✅ Runs on Saturday' : '❌ Does NOT run on Saturday';
      console.log(`  ${info.name}: ${status}`);
      if (!info.repeatsDaily && info.dayIndices.length > 0) {
        console.log(`    Days: ${info.dayIndices.join(', ')}`);
      } else if (info.repeatsDaily) {
        console.log(`    Repeats daily: true`);
      }
      
      if (!info.runsOnSaturday) {
        weekdayShifts.push({ id, ...info });
      }
    });
    
    console.log(`\n❌ Found ${weekdayShifts.length} shifts that should NOT run on Saturday\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    let grandTotalChecklists = 0;
    let grandTotalTasks = 0;
    const deletionsByLocation = {};
    
    // Process each location
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationName = locationData.name || 'Unknown';
      const locationId = locationDoc.id;
      
      console.log(`\n📍 ${locationName} (${locationId})\n`);
      
      // Get Saturday's checklists
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', saturday)
        .get();
      
      console.log(`  Found ${checklistsSnapshot.docs.length} checklists for Saturday\n`);
      
      const toDelete = [];
      let locationTotalTasks = 0;
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'Unknown';
        const shiftId = checklistData.shiftId;
        const shiftInfo = shiftSchedules[shiftId];
        
        if (!shiftInfo) {
          console.log(`  ⚠️  ${templateName}: Unknown shift (${shiftId}) - SKIPPING`);
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
            totalTasks: tasksSnapshot.docs.length,
          });
          
          locationTotalTasks += normalTasks.length;
          console.log(`  ❌ ${templateName} (${shiftInfo.name}): ${normalTasks.length} tasks - WILL DELETE`);
        }
      }
      
      if (toDelete.length === 0) {
        console.log(`  ✅ No incorrectly scheduled checklists found\n`);
        continue;
      }
      
      console.log(`\n  🗑️  Deleting ${toDelete.length} incorrectly scheduled checklists...\n`);
      
      for (const item of toDelete) {
        console.log(`    Deleting: ${item.templateName}`);
        
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
          console.log(`      ✅ Deleted ${tasksSnapshot.docs.length} tasks`);
        }
        
        // Delete the checklist document
        await db
          .collection('organizations').doc(orgId)
          .collection('locations').doc(locationId)
          .collection('daily_checklists').doc(item.id)
          .delete();
        
        console.log(`      ✅ Deleted checklist\n`);
      }
      
      grandTotalChecklists += toDelete.length;
      grandTotalTasks += locationTotalTasks;
      
      deletionsByLocation[locationName] = {
        checklists: toDelete.length,
        tasks: locationTotalTasks,
      };
      
      console.log(`  📊 Location Total: ${toDelete.length} checklists, ${locationTotalTasks} tasks deleted\n`);
      console.log(`${'='.repeat(80)}`);
    }
    
    console.log(`\n✅ CLEANUP COMPLETE!\n`);
    console.log(`Summary by location:`);
    for (const [locationName, stats] of Object.entries(deletionsByLocation)) {
      console.log(`  ${locationName}:`);
      console.log(`    - ${stats.checklists} checklists`);
      console.log(`    - ${stats.tasks} tasks`);
    }
    
    console.log(`\nGrand Total:`);
    console.log(`  - Deleted ${grandTotalChecklists} incorrectly scheduled checklists`);
    console.log(`  - Removed ${grandTotalTasks} tasks from "Missed Yesterday" count\n`);
    console.log(`💡 Weekday shifts should no longer appear in "Missed Tasks from Yesterday" for Saturday.`);
    console.log(`   Refresh the app to see the changes.\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

cleanupAllIncorrectlyScheduledChecklists();
