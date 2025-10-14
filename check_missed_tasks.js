const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkMissedTasks() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz';
    const today = '2025-10-12';
    const yesterday = '2025-10-11';
    
    console.log('🔍 Checking missed tasks from yesterday...\n');
    console.log(`Organization: Hamilton Pork (${orgId})`);
    console.log(`Location: ${locationId}`);
    console.log(`Today: ${today}`);
    console.log(`Yesterday: ${yesterday}\n`);
    
    // Query for carry-forward tasks in today's checklists that came from yesterday
    const tasksSnapshot = await db
      .collectionGroup('tasks')
      .where('organizationId', '==', orgId)
      .where('locationId', '==', locationId)
      .where('dateString', '==', today)
      .where('isCarryForward', '==', true)
      .get();
    
    console.log(`Found ${tasksSnapshot.docs.length} total carry-forward tasks for today\n`);
    
    // Filter to only those from yesterday
    const yesterdayTasks = [];
    for (const doc of tasksSnapshot.docs) {
      const data = doc.data();
      const originalDate = data.originalDate;
      
      let isFromYesterday = false;
      if (typeof originalDate === 'string') {
        isFromYesterday = originalDate === yesterday;
      } else if (originalDate && originalDate._seconds) {
        const date = new Date(originalDate._seconds * 1000);
        const dateStr = date.toISOString().split('T')[0];
        isFromYesterday = dateStr === yesterday;
      }
      
      if (isFromYesterday) {
        yesterdayTasks.push({ id: doc.id, ...data });
      }
    }
    
    console.log(`Tasks from yesterday: ${yesterdayTasks.length}\n`);
    
    // Group by shift/checklist
    const byChecklist = {};
    yesterdayTasks.forEach(task => {
      const checklistName = task.checklistName || task.templateName || 'Unknown';
      if (!byChecklist[checklistName]) {
        byChecklist[checklistName] = [];
      }
      byChecklist[checklistName].push(task);
    });
    
    console.log('Breakdown by checklist:');
    for (const [checklistName, tasks] of Object.entries(byChecklist)) {
      const completed = tasks.filter(t => t.completed).length;
      const incomplete = tasks.length - completed;
      console.log(`\n  📋 ${checklistName}`);
      console.log(`     Total: ${tasks.length} tasks`);
      console.log(`     Completed: ${completed}`);
      console.log(`     Incomplete: ${incomplete}`);
      
      if (tasks.length > 0) {
        console.log(`     Sample tasks:`);
        tasks.slice(0, 3).forEach((task, idx) => {
          console.log(`       ${idx + 1}. ${task.taskName || 'Unnamed'} (${task.completed ? '✓ done' : '✗ incomplete'})`);
        });
      }
    }
    
    // Check yesterday's checklists to see what wasn't completed
    console.log(`\n\n${'='.repeat(80)}`);
    console.log(`\n🔍 Checking yesterday's checklists (${yesterday})...\n`);
    
    const yesterdayChecklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', yesterday)
      .get();
    
    console.log(`Found ${yesterdayChecklistsSnapshot.docs.length} checklists from yesterday\n`);
    
    for (const checklistDoc of yesterdayChecklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      const templateName = checklistData.templateName || 'Unknown';
      
      // Get tasks for this checklist
      const tasksSnap = await checklistDoc.ref.collection('tasks').get();
      const allTasks = tasksSnap.docs.length;
      const completedTasks = tasksSnap.docs.filter(d => d.data().completed === true).length;
      const incompleteTasks = allTasks - completedTasks;
      const carriedForward = tasksSnap.docs.filter(d => d.data().carryForwardAttempted === true).length;
      
      console.log(`📋 ${templateName}`);
      console.log(`   Total tasks: ${allTasks}`);
      console.log(`   Completed: ${completedTasks}`);
      console.log(`   Incomplete: ${incompleteTasks}`);
      console.log(`   Marked for carry-forward: ${carriedForward}`);
      
      if (incompleteTasks > 0) {
        console.log(`   ⚠️  ${incompleteTasks} tasks were not completed`);
      }
      console.log('');
    }
    
    console.log(`\n${'='.repeat(80)}`);
    console.log(`\n💡 SUMMARY:`);
    console.log(`   Carry-forward tasks showing in app: ${yesterdayTasks.length}`);
    console.log(`   These are tasks that were incomplete yesterday and carried forward to today.`);
    console.log(`\n   If the customer believes all tasks were completed yesterday,`);
    console.log(`   then these carry-forward tasks may have been incorrectly created.`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkMissedTasks();
