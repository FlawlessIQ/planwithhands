// Check what tasks are in today's Host Stand checklist
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();
db.settings({
  databaseId: 'planwithhands'
});

async function main() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locationId = 'sYhcOTkX1VkeoPjtPuwZ';
  
  const today = new Date();
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

  console.log('🔍 Checking Today\'s Host Stand Checklist Tasks');
  console.log('═'.repeat(80));

  // Get today's Host Stand checklist
  const checklistsSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', todayStr)
    .where('templateName', '==', 'Host Stand')
    .limit(1)
    .get();

  if (checklistsSnap.empty) {
    console.log('No Host Stand checklist found for today');
    process.exit(1);
  }

  const checklist = checklistsSnap.docs[0];
  console.log(`\nChecklist ID: ${checklist.id}`);
  console.log(`Template: ${checklist.data().templateName}`);

  const tasksSnap = await checklist.ref.collection('tasks').get();
  console.log(`\nTotal tasks: ${tasksSnap.size}\n`);

  const regularTasks = [];
  const carryForwardTasks = [];

  for (const task of tasksSnap.docs) {
    const data = task.data();
    if (data.isCarryForward) {
      carryForwardTasks.push(data);
    } else {
      regularTasks.push(data);
    }
  }

  console.log(`📝 Regular Tasks (${regularTasks.length}):`);
  for (const task of regularTasks) {
    console.log(`  - ${task.taskName || task.name} (completed: ${task.completed})`);
  }

  console.log(`\n🔄 Carry-Forward Tasks (${carryForwardTasks.length}):`);
  for (const task of carryForwardTasks) {
    console.log(`  - ${task.taskName || task.name} (from: ${task.originalDate})`);
  }

  console.log('\n═'.repeat(80));
  console.log('💡 Analysis:');
  console.log('  Regular tasks are TODAY\'s fresh tasks from the template.');
  console.log('  Carry-forward tasks are YESTERDAY\'s incomplete tasks.');
  console.log('  Both types should coexist - user sees ALL tasks they need to complete.');
  console.log('═'.repeat(80));

  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
