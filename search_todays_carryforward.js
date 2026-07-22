const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function searchTodaysCarryForward() {
  try {
    console.log('=== Searching for carry-forward tasks in TODAY (Oct 12) checklists ===\n');
    
    // Get today's checklists
    const todayChecklists = await db
      .collection('organizations')
      .doc('FErQ4pkcrCovJ7T6L13M')
      .collection('locations')
      .doc('abTp8sjidL5QVirAewe6')
      .collection('daily_checklists')
      .where('date', '==', '2025-10-12')
      .get();
    
    console.log(`Found ${todayChecklists.size} checklists for today\n`);
    
    let foundClosingCopy = false;
    
    for (const checklistDoc of todayChecklists.docs) {
      const checklistData = checklistDoc.data();
      
      // Check tasks subcollection for carry-forward tasks
      const tasksSnap = await checklistDoc.ref.collection('tasks')
        .where('isCarryForward', '==', true)
        .get();
      
      if (tasksSnap.size > 0) {
        for (const taskDoc of tasksSnap.docs) {
          const task = taskDoc.data();
          
          // Check if checklistName contains "CLOSING" and "Copy"
          if (task.checklistName && 
              task.checklistName.toLowerCase().includes('closing') &&
              task.checklistName.toLowerCase().includes('copy')) {
            
            foundClosingCopy = true;
            console.log('🔴 FOUND CARRY-FORWARD TASK WITH "CLOSING (Copy)"!');
            console.log(`   Task Doc ID: ${taskDoc.id}`);
            console.log(`   Task Name: ${task.taskName || task.title}`);
            console.log(`   Checklist Name: ${task.checklistName}`);
            console.log(`   Parent Checklist: ${checklistDoc.id}`);
            console.log(`   Template: ${checklistData.templateName}`);
            console.log(`   Original Date: ${task.originalDate}`);
            console.log(`   Carried Into Date: ${task.carriedIntoDate || task.dateString}`);
            console.log(`   Original Checklist ID: ${task.originalChecklistId}`);
            console.log('');
          }
        }
      }
    }
    
    if (!foundClosingCopy) {
      console.log('✅ No carry-forward tasks with "CLOSING (Copy)" found in today\'s checklists');
      console.log('\nThis means the issue might be elsewhere in the app logic or there\'s');
      console.log('a display bug showing stale data from memory/state.');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

searchTodaysCarryForward();
