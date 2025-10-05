// Inspect a specific daily checklist and its tasks in the planwithhands DB.
// Usage: node inspect_checklist.js <orgId> <locationId> <checklistId>

const {Firestore} = require('@google-cloud/firestore');
const admin = require('firebase-admin');
if (!admin.apps.length) { try { admin.initializeApp(); } catch (_) {} }

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function run() {
  const [orgId, locationId, checklistId] = process.argv.slice(2);
  if (!orgId || !locationId || !checklistId) {
    console.error('Missing args. Example: node inspect_checklist.js <orgId> <locationId> <checklistId>');
    process.exit(1);
  }

  const ref = db.collection('organizations').doc(orgId)
    .collection('locations').doc(locationId)
    .collection('daily_checklists').doc(checklistId);

  const snap = await ref.get();
  if (!snap.exists) {
    console.log('Checklist not found');
    return;
  }

  const data = snap.data() || {};
  console.log('Checklist:', { id: snap.id, date: data.date, shiftId: data.shiftId, checklistTemplateIds: data.checklistTemplateIds, createdBy: data.createdBy });

  const tasksSnap = await ref.collection('tasks').limit(50).get();
  const tasks = tasksSnap.docs.map(d => {
    const t = d.data() || {};
    return {
      id: d.id,
      hasTitle: t.title != null,
      hasTaskName: t.taskName != null,
      completed: t.completed,
      isComplete: t.isComplete,
      templateId: t.templateId,
      checklistTemplateId: t.checklistTemplateId,
      templateTaskId: t.templateTaskId,
      order: t.order,
      isCarryForward: t.isCarryForward === true,
      createdBy: t.createdBy,
    };
  });
  console.log('Tasks sample (up to 50):', tasks);
}

run().catch(e => { console.error(e); process.exit(1); });
