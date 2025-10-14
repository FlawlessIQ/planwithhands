const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function debugHamiltonInnMissedTasks() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // The Hamilton Inn
    const today = '2025-10-12';
    
    console.log('🔍 Debugging Hamilton Inn missed tasks...\n');
    console.log(`Location: The Hamilton Inn (${locationId})`);
    console.log(`Today: ${today}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Get today's checklists
    const todayChecklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', today)
      .get();
    
    console.log(`Found ${todayChecklistsSnapshot.docs.length} checklists for today\n`);
    
    let totalCarryForward = 0;
    const carryForwardBreakdown = [];
    
    for (const checklistDoc of todayChecklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      const templateName = checklistData.templateName || 'Unknown';
      
      // Get ALL carry-forward tasks (not just from yesterday)
      const tasksSnapshot = await checklistDoc.ref
        .collection('tasks')
        .where('isCarryForward', '==', true)
        .get();
      
      if (tasksSnapshot.docs.length > 0) {
        console.log(`📋 ${templateName}`);
        console.log(`   Carry-forward tasks: ${tasksSnapshot.docs.length}`);
        
        // Group by original date
        const byDate = {};
        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          const originalDate = taskData.originalDate;
          
          let dateStr = 'unknown';
          if (typeof originalDate === 'string') {
            dateStr = originalDate;
          } else if (originalDate && originalDate._seconds) {
            const date = new Date(originalDate._seconds * 1000);
            dateStr = date.toISOString().split('T')[0];
          }
          
          if (!byDate[dateStr]) {
            byDate[dateStr] = [];
          }
          byDate[dateStr].push({
            id: taskDoc.id,
            title: taskData.title || 'Untitled',
            completed: taskData.completed || false,
          });
        }
        
        // Show breakdown by date
        for (const [date, tasks] of Object.entries(byDate)) {
          console.log(`   From ${date}: ${tasks.length} tasks`);
          totalCarryForward += tasks.length;
          carryForwardBreakdown.push({
            checklist: templateName,
            date,
            count: tasks.length,
            tasks: tasks.slice(0, 3), // Show first 3 tasks
          });
        }
        console.log('');
      }
    }
    
    console.log(`${'='.repeat(80)}\n`);
    console.log(`Total carry-forward tasks found: ${totalCarryForward}\n`);
    
    if (totalCarryForward > 0) {
      console.log('Detailed breakdown:\n');
      for (const item of carryForwardBreakdown) {
        console.log(`${item.checklist} - From ${item.date}:`);
        item.tasks.forEach(t => {
          console.log(`  - ${t.title} ${t.completed ? '✅' : '❌'}`);
        });
        console.log('');
      }
    }
    
    // Also check if there are checklists from OTHER dates that might be showing
    console.log(`${'='.repeat(80)}\n`);
    console.log('Checking for checklists from other dates...\n');
    
    const allChecklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .orderBy('date', 'desc')
      .limit(10)
      .get();
    
    console.log('Most recent checklists:\n');
    for (const doc of allChecklistsSnapshot.docs) {
      const data = doc.data();
      const tasksSnapshot = await doc.ref
        .collection('tasks')
        .where('isCarryForward', '==', true)
        .get();
      
      if (tasksSnapshot.docs.length > 0) {
        console.log(`${data.date} - ${data.templateName}: ${tasksSnapshot.docs.length} carry-forward tasks`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

debugHamiltonInnMissedTasks();
