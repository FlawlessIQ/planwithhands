const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function analyzeYesterdayIncorrectChecklists() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // The Hamilton Inn
    const yesterday = '2025-10-11'; // Saturday
    
    console.log('🔍 Analyzing yesterday\'s checklists for The Hamilton Inn...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Location: The Hamilton Inn (${locationId})`);
    console.log(`Date: ${yesterday} (Saturday)\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Get all shifts to understand their schedules
    const shiftsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('shifts')
      .get();
    
    console.log('📅 Shift Schedules:\n');
    const shiftSchedules = {};
    shiftsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const name = data.name || 'Unknown';
      const daysOfWeek = data.daysOfWeek || [];
      shiftSchedules[doc.id] = {
        name,
        daysOfWeek,
        shouldRunOnSaturday: daysOfWeek.includes(6), // 6 = Saturday
      };
      console.log(`  ${name} (${doc.id})`);
      console.log(`    Days: ${daysOfWeek.join(', ')} ${daysOfWeek.includes(6) ? '✅ Runs on Saturday' : '❌ Does NOT run on Saturday'}`);
      console.log('');
    });
    
    console.log(`${'='.repeat(80)}\n`);
    
    // Get yesterday's checklists
    const checklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', yesterday)
      .get();
    
    console.log(`📋 Yesterday's Checklists (${checklistsSnapshot.docs.length} total):\n`);
    
    const incorrectChecklists = [];
    let totalIncorrectTasks = 0;
    
    for (const checklistDoc of checklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      const templateName = checklistData.templateName || 'Unknown';
      const shiftId = checklistData.shiftId;
      const shiftName = checklistData.shiftName || 'Unknown';
      
      // Get tasks count
      const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
      const normalTasks = tasksSnapshot.docs.filter(d => d.data().isCarryForward !== true);
      const incompleteTasks = normalTasks.filter(d => d.data().completed !== true);
      
      // Check if shift should run on Saturday
      const shiftSchedule = shiftSchedules[shiftId];
      const shouldRun = shiftSchedule ? shiftSchedule.shouldRunOnSaturday : 'UNKNOWN';
      
      if (shouldRun === false || shouldRun === 'UNKNOWN') {
        incorrectChecklists.push({
          id: checklistDoc.id,
          templateName,
          shiftName,
          shiftId: shiftId || 'NO SHIFT ID',
          totalTasks: normalTasks.length,
          incompleteTasks: incompleteTasks.length,
          reason: shouldRun === false ? 'Shift not scheduled for Saturday' : 'Unknown shift',
        });
        totalIncorrectTasks += incompleteTasks.length;
      }
      
      const status = shouldRun === true ? '✅' : (shouldRun === false ? '❌ SHOULD NOT RUN' : '⚠️  UNKNOWN SHIFT');
      console.log(`  ${templateName} (${shiftName})`);
      console.log(`    Shift ID: ${shiftId || 'MISSING'}`);
      console.log(`    Status: ${status}`);
      console.log(`    Tasks: ${incompleteTasks.length}/${normalTasks.length} incomplete`);
      console.log('');
    }
    
    console.log(`${'='.repeat(80)}\n`);
    
    if (incorrectChecklists.length > 0) {
      console.log(`\n⚠️  INCORRECT CHECKLISTS FOUND: ${incorrectChecklists.length}\n`);
      incorrectChecklists.forEach(c => {
        console.log(`  📋 ${c.templateName}`);
        console.log(`     Shift: ${c.shiftName} (${c.shiftId})`);
        console.log(`     Reason: ${c.reason}`);
        console.log(`     Incomplete tasks: ${c.incompleteTasks}`);
        console.log(`     Checklist ID: ${c.id}`);
        console.log('');
      });
      
      console.log(`🎯 Total incorrect incomplete tasks: ${totalIncorrectTasks}\n`);
      console.log(`💡 These checklists should be deleted because they were generated`);
      console.log(`   for shifts that don't run on Saturdays.\n`);
    } else {
      console.log(`\n✅ All checklists appear to be correctly scheduled.\n`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

analyzeYesterdayIncorrectChecklists();
