// Repair tasks for a single checklist: convert legacy fields to the current schema.
// - taskName from title
// - completed from isComplete
// - checklistTemplateId from templateId
// - templateTaskId from docId suffix after '<templateId>_' if present

const {Firestore} = require('@google-cloud/firestore');
const admin = require('firebase-admin');
if (!admin.apps.length) { try { admin.initializeApp(); } catch (_) {} }

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

function inferTemplateTaskId(docId, templateId) {
  if (!docId || !templateId) return null;
  const prefix = `${templateId}_`;
  if (docId.startsWith(prefix)) return docId.slice(prefix.length);
  return null;
}

async function run() {
  const [orgId, locationId, checklistId] = process.argv.slice(2);
  if (!orgId || !locationId || !checklistId) {
    console.error('Usage: node repair_tasks_schema_for_checklist.js <orgId> <locationId> <checklistId>');
    process.exit(1);
  }

  const base = db.collection('organizations').doc(orgId)
    .collection('locations').doc(locationId)
    .collection('daily_checklists').doc(checklistId);

  const tasksSnap = await base.collection('tasks').get();
  let updated = 0;
  const batch = db.batch();
  for (const d of tasksSnap.docs) {
    const t = d.data() || {};
    const patch = {};
    if (t.title && !t.taskName) patch.taskName = t.title;
    if (typeof t.completed === 'undefined' && typeof t.isComplete === 'boolean') patch.completed = t.isComplete === true;
    if (!t.checklistTemplateId && t.templateId) patch.checklistTemplateId = t.templateId;
    if (!t.templateTaskId) {
      const inferred = inferTemplateTaskId(d.id, t.templateId || t.checklistTemplateId);
      if (inferred) patch.templateTaskId = inferred;
    }
    if (Object.keys(patch).length > 0) {
      batch.set(d.ref, patch, { merge: true });
      updated++;
    }
  }
  if (updated > 0) await batch.commit();
  console.log(`Checklist ${checklistId}: updated ${updated}/${tasksSnap.size} tasks.`);
}

run().catch(e => { console.error(e); process.exit(1); });
