const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function analyzeYesterdayCompletionStatus() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const yesterday = '2025-10-11';
    
    console.log('🔍 Analyzing yesterday\'s task completion status...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Yesterday: ${yesterday}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    let grandTotalIncomplete = 0;
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationName = locationData.name || 'Unknown';
      const locationId = locationDoc.id;
      
      console.log(`📍 ${locationName} (${locationId})\n`);
      
      // Get yesterday's checklists
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', yesterday)
        .get();
      
      console.log(`  Found ${checklistsSnapshot.docs.length} checklists for yesterday\n`);
      
      let locationIncomplete = 0;
      const checklistSummary = [];
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'Unknown';
        
        // Get all tasks (subcollection)
        const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
        
        let normalTasks = 0;
        let completedNormal = 0;
        let incompleteNormal = 0;
        let carryForwardTasks = 0;
        
        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          const isCarryForward = taskData.isCarryForward === true;
          const isCompleted = taskData.completed === true || taskData.isCompleted === true;
          
          if (isCarryForward) {
            carryForwardTasks++;
          } else {
            normalTasks++;
            if (isCompleted) {
              completedNormal++;
            } else {
              incompleteNormal++;
            }
          }
        }
        
        if (normalTasks > 0) {
          checklistSummary.push({
            name: templateName,
            total: normalTasks,
            completed: completedNormal,
            incomplete: incompleteNormal,
            carryForward: carryForwardTasks,
          });
          
          locationIncomplete += incompleteNormal;
        }
      }
      
      // Display summary
      if (checklistSummary.length > 0) {
        console.log(`  Checklist breakdown:\n`);
        checklistSummary.forEach(c => {
          const completionRate = c.total > 0 ? Math.round((c.completed / c.total) * 100) : 0;
          console.log(`  📋 ${c.name}`);
          console.log(`     Normal tasks: ${c.completed}/${c.total} completed (${completionRate}%)`);
          if (c.incomplete > 0) {
            console.log(`     ⚠️  ${c.incomplete} incomplete tasks`);
          }
          if (c.carryForward > 0) {
            console.log(`     ❌ ${c.carryForward} carry-forward tasks still exist!`);
          }
          console.log('');
        });
        
        console.log(`  📊 Location Total: ${locationIncomplete} incomplete normal tasks\n`);
        grandTotalIncomplete += locationIncomplete;
      } else {
        console.log(`  ✅ No checklists or all tasks completed\n`);
      }
      
      console.log(`${'='.repeat(80)}\n`);
    }
    
    console.log(`\n🎯 TOTAL INCOMPLETE TASKS FROM YESTERDAY: ${grandTotalIncomplete}\n`);
    console.log(`This is what the dashboard "MISSED YESTERDAY" count should show.\n`);
    
    if (grandTotalIncomplete > 0) {
      console.log(`💡 These are legitimate incomplete tasks from yesterday.`);
      console.log(`   They should either:`);
      console.log(`   1. Be marked as completed if they were actually done`);
      console.log(`   2. Remain as missed tasks if they truly weren't completed\n`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

analyzeYesterdayCompletionStatus();
