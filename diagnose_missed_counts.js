#!/usr/bin/env node

/**
 * Diagnostic: Count actual CF tasks for today (2025-10-05) by shift and compare to what's shown.
 * Focus on org 3qjYzHagWmfbnMieJ1aj, location sYhcOTkX1VkeoPjtPuwZ.
 */

const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function diagnoseMissedCounts() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locationId = 'sYhcOTkX1VkeoPjtPuwZ';
  const today = '2025-10-05';
  const yesterday = '2025-10-04';

  console.log(`\n🔍 Diagnosing Missed Tasks for ${today} (org=${orgId}, loc=${locationId})`);
  console.log(`   Looking for CF tasks with originalDate=${yesterday}\n`);

  // Get all daily_checklists for today
  const checklistsSnap = await db
    .collection('organizations').doc(orgId)
    .collection('locations').doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', today)
    .get();

  console.log(`Found ${checklistsSnap.docs.length} checklists for ${today}\n`);

  const shiftCounts = new Map();
  let totalCF = 0;

  for (const cl of checklistsSnap.docs) {
    const clData = cl.data();
    const shiftId = clData.shiftId;
    const shiftName = clData.templateName || clData.checklistName || 'Unknown';
    
    // Get tasks subcollection
    const tasksSnap = await cl.ref.collection('tasks')
      .where('isCarryForward', '==', true)
      .get();

    // Filter by originalDate == yesterday
    let cfCount = 0;
    const cfTasks = [];
    for (const t of tasksSnap.docs) {
      const tData = t.data();
      const od = tData.originalDate;
      if (od === yesterday || (od && od.toString() === yesterday)) {
        cfCount++;
        cfTasks.push({
          id: t.id,
          name: tData.taskName || tData.name,
          originalTaskId: tData.originalTaskId,
          originalChecklistId: tData.originalChecklistId,
        });
      }
    }

    if (cfCount > 0 || true) {
      const key = `${shiftName} (${shiftId})`;
      const existing = shiftCounts.get(key) || { count: 0, tasks: [] };
      existing.count += cfCount;
      existing.tasks.push(...cfTasks);
      shiftCounts.set(key, existing);
      totalCF += cfCount;
    }
  }

  console.log('📊 Actual CF Task Counts by Shift:\n');
  for (const [shift, data] of shiftCounts.entries()) {
    console.log(`   ${shift}: ${data.count} CF tasks`);
    if (data.count > 0 && data.count <= 15) {
      data.tasks.forEach(t => console.log(`      - ${t.name} (${t.id})`));
    }
  }

  console.log(`\n🔢 Total CF tasks for yesterday across all shifts: ${totalCF}`);
  console.log(`\n💡 Compare these counts to what's shown in the dashboard.`);
  console.log(`   If dashboard shows higher numbers, there may be:`);
  console.log(`   - Duplicate CF tasks (same name, different doc IDs)`);
  console.log(`   - CF tasks with wrong originalDate`);
  console.log(`   - Counting logic including non-CF or old CF tasks`);
}

diagnoseMissedCounts().then(() => process.exit(0)).catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
