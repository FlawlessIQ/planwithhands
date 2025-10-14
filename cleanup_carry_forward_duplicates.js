const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

/**
 * Clean up incorrectly created carry-forward tasks
 * 
 * This script:
 * 1. Removes carry-forward tasks from today that came from yesterday's duplicates
 * 2. Optionally cleans up yesterday's duplicate carry-forward tasks
 */

async function cleanupCarryForwardTasks() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const today = '2025-10-12';
    const yesterday = '2025-10-11';
    
    console.log('🧹 Cleaning up incorrectly created carry-forward tasks...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Today: ${today}`);
    console.log(`Yesterday: ${yesterday}\n`);
    
    // Get all locations in the organization
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`Found ${locationsSnapshot.docs.length} locations to clean\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    let grandTotalDeletedToday = 0;
    let grandTotalDeletedYesterday = 0;
    
    // Process each location
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationId = locationDoc.id;
      const locationName = locationData.name || 'Unknown';
      
      console.log(`\n📍 LOCATION: ${locationName} (${locationId})\n`);
    
    // Step 1: Remove carry-forward tasks from today that came from yesterday
    console.log(`${'='.repeat(80)}`);
    console.log('STEP 1: Removing carry-forward tasks from today\'s checklists\n');
    
    const todayChecklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', today)
      .get();
    
    console.log(`Found ${todayChecklistsSnapshot.docs.length} checklists for today\n`);
    
    let totalDeletedToday = 0;
    
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
        console.log(`📋 ${templateName}`);
        console.log(`   Deleting ${yesterdayTasks.length} carry-forward tasks from yesterday...`);
        
        const batch = db.batch();
        yesterdayTasks.forEach(taskDoc => {
          batch.delete(taskDoc.ref);
        });
        
        await batch.commit();
        totalDeletedToday += yesterdayTasks.length;
        console.log(`   ✅ Deleted ${yesterdayTasks.length} tasks\n`);
      }
    }
    
    console.log(`✅ Deleted ${totalDeletedToday} carry-forward tasks from today\n`);
    
    // Step 2: Clean up yesterday's checklists
    console.log(`\n${'='.repeat(80)}`);
    console.log('STEP 2: Cleaning up yesterday\'s duplicate carry-forward tasks\n');
    
    const yesterdayChecklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', yesterday)
      .get();
    
    console.log(`Found ${yesterdayChecklistsSnapshot.docs.length} checklists from yesterday\n`);
    
    let totalDeletedYesterday = 0;
    
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
        console.log(`📋 ${templateName}`);
        console.log(`   Total tasks: ${allTasksSnapshot.docs.length}`);
        console.log(`   Carry-forward tasks (duplicates): ${carryForwardTasks.length}`);
        console.log(`   Deleting duplicate carry-forward tasks...`);
        
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
        
        console.log(`   ✅ Deleted ${carryForwardTasks.length} duplicate tasks`);
        console.log(`   📊 Updated metrics: ${completedTasks}/${remainingTasks} completed\n`);
      }
    }
    
    console.log(`✅ Deleted ${totalDeletedYesterday} duplicate carry-forward tasks from yesterday\n`);
    
    // Summary
    console.log(`\n${'='.repeat(80)}`);
    console.log('\n✅ CLEANUP COMPLETE!\n');
    console.log(`Summary:`);
    console.log(`  - Deleted ${totalDeletedToday} incorrect carry-forward tasks from today`);
    console.log(`  - Deleted ${totalDeletedYesterday} duplicate carry-forward tasks from yesterday`);
    console.log(`  - Total cleaned up: ${totalDeletedToday + totalDeletedYesterday} tasks\n`);
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
