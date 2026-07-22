#!/usr/bin/env node

/**
 * Verify today's checklists across all orgs; for any with 0 tasks, reseed from template tasks.
 * This mirrors the seeding logic in functions/src/dailyGenerator.ts (simplified, no carry-forward).
 */

const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function seedFromTemplate(orgId, locationId, checklistRef, checklistData) {
  const templateId = checklistData.checklistTemplateId || checklistData.templateId;
  if (!templateId) {
    console.log(`      ⚠️ No templateId on checklist ${checklistRef.id}; skip reseed`);
    return 0;
  }
  const orgRef = db.collection('organizations').doc(orgId);
  const tRef = orgRef.collection('checklist_templates').doc(templateId);
  const tSnap = await tRef.get();
  if (!tSnap.exists) {
    console.log(`      ⚠️ Template ${templateId} not found; skip reseed`);
    return 0;
  }
  const tName = (tSnap.get('name') || '').toString();
  const tasksSnap = await tRef.collection('tasks').orderBy('order').get();
  if (tasksSnap.empty) {
    console.log(`      ⚠️ Template ${templateId} has no tasks; skip reseed`);
    return 0;
  }
  const batch = db.batch();
  let created = 0;
  let order = 0;
  tasksSnap.forEach(taskDoc => {
    const t = taskDoc.data() || {};
    const taskId = `${templateId}_${taskDoc.id}`;
    const taskRef = checklistRef.collection('tasks').doc(taskId);
    const taskData = {
      taskId,
      taskName: t.name || t.title || t.description || 'Task',
      createdAt: admin.firestore.Timestamp.now(),
      createdBy: 'verify-reseed',
      completed: false,
      isCarryForward: false,
      isCarryForwardEligible: t.isCarryForwardEligible === true || t.photoRequired === true,
      templateTaskId: taskDoc.id,
      templateId,
      templateName: tName,
      organizationId: orgId,
      locationId,
      shiftId: checklistData.shiftId,
      checklistId: checklistRef.id,
      checklistTemplateId: templateId,
      checklistName: tName,
      dateString: checklistData.date || checklistData.dateString,
      order: typeof t.order === 'number' ? t.order : order,
    };
    batch.set(taskRef, taskData, { merge: false });
    order++;
    created++;
  });
  await batch.commit();
  return created;
}

async function verifyAndReseed() {
  const today = new Date().toISOString().split('T')[0];
  console.log(`🔎 Verify + reseed empty checklists for ${today}`);
  const orgs = await db.collection('organizations').get();
  let totalEmpties = 0;
  let totalSeeded = 0;
  for (const org of orgs.docs) {
    const orgId = org.id;
    const locs = await db.collection('organizations').doc(orgId).collection('locations').get();
    for (const loc of locs.docs) {
      const locationId = loc.id;
      const cls = await db.collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', today)
        .get();
      for (const cl of cls.docs) {
        const tasksSnap = await cl.ref.collection('tasks').limit(1).get();
        if (tasksSnap.empty) {
          totalEmpties++;
          console.log(`   🌱 Reseed ${orgId}/${locationId}/${cl.id}`);
          const seeded = await seedFromTemplate(orgId, locationId, cl.ref, cl.data());
          totalSeeded += seeded;
          console.log(`      ➕ Seeded ${seeded} tasks`);
        }
      }
    }
  }
  console.log(`\n✅ Done. Empty checklists: ${totalEmpties}, tasks seeded: ${totalSeeded}`);
}

verifyAndReseed().then(() => process.exit(0)).catch(err => {
  console.error('❌ verify_and_reseed_today failed', err);
  process.exit(1);
});
