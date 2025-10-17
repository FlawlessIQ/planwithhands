// Manually trigger carry-forward for missed tasks
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

async function carryForwardMissedTasks(orgId, locationId, yesterday, today) {
  const yString = yesterday;
  const todayStr = today;

  console.log(`\n🔄 Processing location ${locationId}...`);

  const ySnapshots = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', yString)
    .get();

  console.log(`  Found ${ySnapshots.size} yesterday's checklists`);
  
  let totalCarriedForward = 0;

  for (const doc of ySnapshots.docs) {
    const data = doc.data();
    const shiftId = data.shiftId;
    const templateName = data.templateName;
    const originalTemplateId = data.checklistTemplateId;

    if (!shiftId || !originalTemplateId) {
      console.log(`  ⚠️  Skipping ${templateName}: missing shiftId or templateId`);
      continue;
    }

    // Get tasks from subcollection
    const tasksSnap = await doc.ref.collection('tasks').get();
    const tasksList = tasksSnap.docs.map(d => ({
      id: d.id,
      ...d.data()
    }));

    let anyChanges = false;
    const carryForwardTasks = [];

    for (const taskMap of tasksList) {
      const isCompleted = taskMap.completed === true || taskMap.isCompleted === true;
      const carryForwardAttempted = taskMap.carryForwardAttempted === true;

      if (!isCompleted && !carryForwardAttempted) {
        anyChanges = true;

        const originalTaskId = taskMap.taskId || taskMap.id;
        const originalName = taskMap.taskName || taskMap.description || taskMap.title || taskMap.name || 'Unknown Task';

        carryForwardTasks.push({
          originalTaskId,
          taskName: originalName,
          taskMap
        });

        // Mark as attempted in yesterday's task
        await doc.ref.collection('tasks').doc(taskMap.id).update({
          carryForwardAttempted: true
        });
      }
    }

    if (anyChanges && carryForwardTasks.length > 0) {
      console.log(`  📝 ${templateName}: ${carryForwardTasks.length} tasks to carry forward`);

      // Generate today's checklist ID
      const todayChecklistId = `${orgId}_${locationId}_${shiftId}_${originalTemplateId}_${todayStr}`;

      const todayRef = db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(todayChecklistId);

      // Ensure today's checklist exists
      await todayRef.set({
        id: todayChecklistId,
        checklistTemplateId: originalTemplateId,
        shiftId: shiftId,
        locationId: locationId,
        organizationId: orgId,
        date: todayStr,
        templateName: templateName,
        jobTypes: data.jobTypes || data.jobType,
        isCompleted: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      const tasksColl = todayRef.collection('tasks');

      // Get existing CARRY-FORWARD tasks to avoid duplicates
      // (Regular tasks with same names are OK - they're today's recurring tasks)
      const existingCFTasksSnap = await tasksColl.where('isCarryForward', '==', true).get();
      const existingCFTaskIds = new Set();
      for (const t of existingCFTasksSnap.docs) {
        const tData = t.data();
        if (tData.originalTaskId) {
          existingCFTaskIds.add(tData.originalTaskId);
        }
      }

      // Insert carry-forward tasks
      for (const cf of carryForwardTasks) {
        if (existingCFTaskIds.has(cf.originalTaskId)) {
          console.log(`    ⏭️  Skipping already carried forward: ${cf.taskName}`);
          continue;
        }

        const cfTaskId = `${todayChecklistId}_cf_${cf.originalTaskId}_${Date.now()}`;
        const taskData = {
          taskId: cfTaskId,
          taskName: cf.taskName,
          completed: false,
          isCarryForward: true,
          originalTaskId: cf.originalTaskId,
          originalDate: yString,
          originalChecklistId: doc.id,
          organizationId: orgId,
          locationId: locationId,
          dateString: todayStr,
          shiftId: shiftId,
          checklistId: todayChecklistId,
          checklistTemplateId: originalTemplateId,
          checklistName: templateName,
          templateName: templateName,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        // Only add description if it exists
        if (cf.taskMap.description !== undefined) {
          taskData.description = cf.taskMap.description;
        }
        
        await tasksColl.doc(cfTaskId).set(taskData);

        totalCarriedForward++;
        existingTaskNames.add(normName);
      }

      console.log(`    ✅ Created ${carryForwardTasks.length} carry-forward tasks`);
    }
  }

  return totalCarriedForward;
}

async function main() {
  console.log('🚀 Manual Carry-Forward Trigger');
  console.log('Organization: 3qjYzHagWmfbnMieJ1aj');
  console.log('═'.repeat(80));

  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

  console.log(`\n📅 Yesterday: ${yesterdayStr}`);
  console.log(`📅 Today: ${todayStr}`);

  // Get all locations
  const locationsSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .get();

  console.log(`\n🏢 Found ${locationsSnap.size} locations`);

  let grandTotal = 0;
  for (const loc of locationsSnap.docs) {
    const total = await carryForwardMissedTasks(orgId, loc.id, yesterdayStr, todayStr);
    grandTotal += total;
  }

  console.log('\n' + '═'.repeat(80));
  console.log(`✅ Carry-forward complete!`);
  console.log(`📊 Total tasks carried forward: ${grandTotal}`);
  console.log('═'.repeat(80));

  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
