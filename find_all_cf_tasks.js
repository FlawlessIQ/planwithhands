// Find ALL carry-forward tasks across all today's checklists
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

  console.log('🔍 Finding ALL Carry-Forward Tasks for Today');
  console.log('═'.repeat(80));

  const checklistsSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', todayStr)
    .get();

  console.log(`\nFound ${checklistsSnap.size} checklists for today\n`);

  let totalCF = 0;
  const cfByTemplate = {};

  for (const checklist of checklistsSnap.docs) {
    const data = checklist.data();
    const templateName = data.templateName;
    const jobTypes = data.jobTypes || data.jobType;

    const tasksSnap = await checklist.ref.collection('tasks').get();
    let cfCount = 0;

    for (const task of tasksSnap.docs) {
      const tData = task.data();
      if (tData.isCarryForward) {
        cfCount++;
      }
    }

    if (cfCount > 0) {
      totalCF += cfCount;
      cfByTemplate[templateName] = (cfByTemplate[templateName] || 0) + cfCount;
      console.log(`✅ ${templateName}: ${cfCount} carry-forward tasks`);
      console.log(`   JobTypes: ${jobTypes ? JSON.stringify(jobTypes) : '(none)'}`);
      console.log(`   Checklist ID: ${checklist.id.slice(-30)}`);
    } else {
      console.log(`❌ ${templateName}: 0 carry-forward tasks`);
      console.log(`   JobTypes: ${jobTypes ? JSON.stringify(jobTypes) : '(none)'}`);
    }
  }

  console.log('\n' + '═'.repeat(80));
  console.log(`Total carry-forward tasks: ${totalCF}`);
  console.log('\nBy template:');
  for (const [tmpl, count] of Object.entries(cfByTemplate)) {
    console.log(`  ${tmpl}: ${count}`);
  }
  console.log('═'.repeat(80));

  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
