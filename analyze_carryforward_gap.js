// Analyze why only 15 tasks were carried forward when 32 were missed
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
  console.log('🔍 Analyzing Carry-Forward Gap');
  console.log('Expected: 32 missed tasks → Found: 15 carry-forward tasks');
  console.log('Missing: 17 tasks');
  console.log('═'.repeat(80));

  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locationId = 'sYhcOTkX1VkeoPjtPuwZ';
  
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

  console.log(`\n📅 Yesterday: ${yesterdayStr}`);
  console.log(`📅 Today: ${todayStr}`);

  // Get yesterday's checklists
  const yesterdayChecks = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', yesterdayStr)
    .get();

  console.log(`\n📋 Yesterday's Checklists (${yesterdayChecks.size}):`);
  
  const yesterdayTasksByChecklist = {};
  
  for (const check of yesterdayChecks.docs) {
    const data = check.data();
    const templateName = data.templateName || 'Unknown';
    
    // Get tasks from subcollection
    const tasksSnap = await check.ref.collection('tasks').get();
    
    let incompleteTasks = 0;
    let carryForwardAttempted = 0;
    
    for (const task of tasksSnap.docs) {
      const tData = task.data();
      const completed = tData.completed === true || tData.isCompleted === true;
      const attempted = tData.carryForwardAttempted === true;
      
      if (!completed) {
        incompleteTasks++;
        if (attempted) {
          carryForwardAttempted++;
        }
      }
    }
    
    yesterdayTasksByChecklist[check.id] = {
      templateName,
      totalTasks: tasksSnap.size,
      incompleteTasks,
      carryForwardAttempted
    };
    
    console.log(`\n  ${templateName} (${check.id.slice(-18)})`);
    console.log(`    Total tasks: ${tasksSnap.size}`);
    console.log(`    Incomplete: ${incompleteTasks}`);
    console.log(`    Marked carryForwardAttempted: ${carryForwardAttempted}`);
  }

  // Get today's checklists and count carry-forward tasks
  const todayChecks = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', todayStr)
    .get();

  console.log(`\n\n📋 Today's Checklists (${todayChecks.size}):`);
  
  let totalCarryForward = 0;
  const cfByTemplate = {};
  
  for (const check of todayChecks.docs) {
    const data = check.data();
    const templateName = data.templateName || 'Unknown';
    
    // Get carry-forward tasks
    const cfTasksSnap = await check.ref
      .collection('tasks')
      .where('isCarryForward', '==', true)
      .get();
    
    let fromYesterday = 0;
    for (const task of cfTasksSnap.docs) {
      const tData = task.data();
      const origDate = tData.originalDate;
      
      if (origDate === yesterdayStr || 
          (origDate && origDate.toDate && 
           origDate.toDate().toISOString().startsWith(yesterdayStr))) {
        fromYesterday++;
      }
    }
    
    if (fromYesterday > 0) {
      totalCarryForward += fromYesterday;
      cfByTemplate[templateName] = (cfByTemplate[templateName] || 0) + fromYesterday;
      
      console.log(`\n  ${templateName} (${check.id.slice(-18)})`);
      console.log(`    Carry-forward from yesterday: ${fromYesterday}`);
    }
  }

  console.log(`\n\n📊 Summary by Template:`);
  console.log('═'.repeat(80));
  
  const allTemplates = new Set([
    ...Object.keys(yesterdayTasksByChecklist).map(k => yesterdayTasksByChecklist[k].templateName),
    ...Object.keys(cfByTemplate)
  ]);
  
  let totalYesterdayIncomplete = 0;
  
  for (const template of allTemplates) {
    const yesterdayData = Object.values(yesterdayTasksByChecklist).filter(v => v.templateName === template);
    const yesterdayIncomplete = yesterdayData.reduce((sum, v) => sum + v.incompleteTasks, 0);
    const todayCF = cfByTemplate[template] || 0;
    const gap = yesterdayIncomplete - todayCF;
    
    totalYesterdayIncomplete += yesterdayIncomplete;
    
    console.log(`\n${template}:`);
    console.log(`  Yesterday incomplete: ${yesterdayIncomplete}`);
    console.log(`  Today carry-forward: ${todayCF}`);
    if (gap > 0) {
      console.log(`  ❌ MISSING: ${gap} tasks not carried forward!`);
    } else {
      console.log(`  ✅ All tasks carried forward`);
    }
  }

  console.log('\n' + '═'.repeat(80));
  console.log(`Total yesterday incomplete: ${totalYesterdayIncomplete}`);
  console.log(`Total today carry-forward: ${totalCarryForward}`);
  console.log(`Gap: ${totalYesterdayIncomplete - totalCarryForward} tasks`);
  console.log('═'.repeat(80));
  
  console.log('\n💡 Possible reasons for missing tasks:');
  console.log('  1. Tasks marked carryForwardAttempted=true but not actually carried forward');
  console.log('  2. Carry-forward ran before all tasks were marked incomplete');
  console.log('  3. Template ID mismatch preventing carry-forward creation');
  console.log('  4. Today\'s checklist not created yet for some shifts');
  
  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
