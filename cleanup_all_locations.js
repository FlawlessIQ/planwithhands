const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

/**
 * Clean up incorrectly created carry-forward tasks across all locations
 * 
 * This script:
 * 1. Removes carry-forward tasks from today that came from yesterday's duplicates
 * 2. Optionally cleans up yesterday's duplicate carry-forward tasks
 */

async function cleanupLocationCarryForwardTasks(orgId, locationId, locationName, today, yesterday) {
  console.log(`\n📍 LOCATION: ${locationName} (${locationId})\n`);
  
  let totalDeletedToday = 0;
  let totalDeletedYesterday = 0;
  
  // Step 1: Remove carry-forward tasks from today that came from yesterday
  console.log(`  🔍 Checking today's checklists...\n`);
  
  const todayChecklistsSnapshot = await db
    .collection('organizations').doc(orgId)
    .collection('locations').doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', today)
    .get();
  
  console.log(`  Found ${todayChecklistsSnapshot.docs.length} checklists for today\n`);
  
  for (const checklistDoc of todayChecklistsSnapshot.docs) {
    const checklistData = checklistDoc.data();
    const templateName = checklistData.templateName || 'Unknown';
    
    // Get carry-forward tasks that came from yesterday
    const tasksSnapshot = await checklistDoc.ref
      .collection('tasks')
      .where('isCarryForward', '==', true)
      .get();
    
    const yesterdayTasks = [];
    for (const taskDoc of tasksSnapshot.docs) {
      const taskData = taskDoc.data();
      const originalDate = taskData.originalDate;
      
      let isFromYesterday = false;
      if (typeof originalDate === 'string') {
        isFromYesterday = originalDate === yesterday;
      } else if (originalDate && originalDate._seconds) {
        const date = new Date(originalDate._seconds * 1000);
        const dateStr = date.toISOString().split('T')[0];
        isFromYesterday = dateStr === yesterday;
      }
      
      if (isFromYesterday) {
        yesterdayTasks.push(taskDoc);
      }
    }
    
    if (yesterdayTasks.length > 0) {
      console.log(`  📋 ${templateName}`);
      console.log(`     Deleting ${yesterdayTasks.length} carry-forward tasks from yesterday...`);
      
      const batch = db.batch();
      yesterdayTasks.forEach(taskDoc => {
        batch.delete(taskDoc.ref);
      });
      
      await batch.commit();
      totalDeletedToday += yesterdayTasks.length;
      console.log(`     ✅ Deleted ${yesterdayTasks.length} tasks\n`);
    }
  }
  
  if (totalDeletedToday > 0) {
    console.log(`  ✅ Deleted ${totalDeletedToday} carry-forward tasks from today\n`);
  } else {
    console.log(`  ✅ No carry-forward tasks to delete from today\n`);
  }
  
  // Step 2: Clean up yesterday's checklists
  console.log(`  🔍 Checking yesterday's checklists...\n`);
  
  const yesterdayChecklistsSnapshot = await db
    .collection('organizations').doc(orgId)
    .collection('locations').doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', yesterday)
    .get();
  
  console.log(`  Found ${yesterdayChecklistsSnapshot.docs.length} checklists from yesterday\n`);
  
  for (const checklistDoc of yesterdayChecklistsSnapshot.docs) {
    const checklistData = checklistDoc.data();
    const templateName = checklistData.templateName || 'Unknown';
    
    // Get all tasks
    const allTasksSnapshot = await checklistDoc.ref.collection('tasks').get();
    
    // Identify carry-forward tasks (these should have been normal tasks)
    const carryForwardTasks = allTasksSnapshot.docs.filter(d => 
      d.data().isCarryForward === true
    );
    
    if (carryForwardTasks.length > 0) {
      console.log(`  📋 ${templateName}`);
      console.log(`     Total tasks: ${allTasksSnapshot.docs.length}`);
      console.log(`     Carry-forward tasks (duplicates): ${carryForwardTasks.length}`);
      console.log(`     Deleting duplicate carry-forward tasks...`);
      
      const batch = db.batch();
      carryForwardTasks.forEach(taskDoc => {
        batch.delete(taskDoc.ref);
      });
      
      await batch.commit();
      totalDeletedYesterday += carryForwardTasks.length;
      
      // Update checklist metrics
      const remainingTasks = allTasksSnapshot.docs.length - carryForwardTasks.length;
      const completedTasks = allTasksSnapshot.docs.filter(d => 
        d.data().isCarryForward !== true && d.data().completed === true
      ).length;
      
      await checklistDoc.ref.update({
        totalItems: remainingTasks,
        completedItems: completedTasks,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`     ✅ Deleted ${carryForwardTasks.length} duplicate tasks`);
      console.log(`     📊 Updated metrics: ${completedTasks}/${remainingTasks} completed\n`);
    }
  }
  
  if (totalDeletedYesterday > 0) {
    console.log(`  ✅ Deleted ${totalDeletedYesterday} duplicate carry-forward tasks from yesterday\n`);
  } else {
    console.log(`  ✅ No carry-forward tasks to delete from yesterday\n`);
  }
  
  return {
    locationName,
    deletedToday: totalDeletedToday,
    deletedYesterday: totalDeletedYesterday,
  };
}

async function cleanupCarryForwardTasks() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const today = '2025-10-12';
    const yesterday = '2025-10-11';
    
    console.log('🧹 Cleaning up incorrectly created carry-forward tasks...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Today: ${today}`);
    console.log(`Yesterday: ${yesterday}\n`);
    console.log(`${'='.repeat(80)}`);
    
    // Get all locations in the organization
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`\nFound ${locationsSnapshot.docs.length} locations to clean\n`);
    console.log(`${'='.repeat(80)}`);
    
    const results = [];
    
    // Process each location
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationId = locationDoc.id;
      const locationName = locationData.name || 'Unknown';
      
      const result = await cleanupLocationCarryForwardTasks(
        orgId,
        locationId,
        locationName,
        today,
        yesterday
      );
      
      results.push(result);
      console.log(`${'='.repeat(80)}`);
    }
    
    // Summary
    const grandTotalToday = results.reduce((sum, r) => sum + r.deletedToday, 0);
    const grandTotalYesterday = results.reduce((sum, r) => sum + r.deletedYesterday, 0);
    
    console.log('\n✅ CLEANUP COMPLETE!\n');
    console.log(`Summary by location:`);
    results.forEach(r => {
      console.log(`  ${r.locationName}:`);
      console.log(`    - Today: ${r.deletedToday} tasks`);
      console.log(`    - Yesterday: ${r.deletedYesterday} tasks`);
    });
    console.log(`\nGrand Total:`);
    console.log(`  - Deleted ${grandTotalToday} incorrect carry-forward tasks from today`);
    console.log(`  - Deleted ${grandTotalYesterday} duplicate carry-forward tasks from yesterday`);
    console.log(`  - Total cleaned up: ${grandTotalToday + grandTotalYesterday} tasks\n`);
    console.log(`💡 The "Missed Tasks from Yesterday" count should now be 0 or much lower.`);
    console.log(`   Refresh the app to see the changes.\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

cleanupCarryForwardTasks();
