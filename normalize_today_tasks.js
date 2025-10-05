// Normalize today's tasks across all orgs to align with current schema.
// For each task missing fields, set:
// - taskName from title/name/description
// - completed from isComplete (default false)
// - checklistTemplateId from templateId if missing
// - templateTaskId inferred from document id if it matches '<templateId>_<templateTaskId>'

const {Firestore} = require('@google-cloud/firestore');
const admin = require('firebase-admin');
if (!admin.apps.length) { try { admin.initializeApp(); } catch (_) {} }

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

function todayISO() { return new Date().toISOString().slice(0,10); }

function inferTemplateTaskId(docId, templateId) {
  if (!docId || !templateId) return null;
  const prefix = `${templateId}_`;
  if (docId.startsWith(prefix)) return docId.slice(prefix.length);
  return null;
}

async function run() {
  const date = todayISO();
  let total = 0, updated = 0;

  const orgs = await db.collection('organizations').get();
  for (const orgDoc of orgs.docs) {
    const orgId = orgDoc.id;
    const orgRef = db.collection('organizations').doc(orgId);
    const locs = await orgRef.collection('locations').get();

    for (const loc of locs.docs) {
      const locationId = loc.id;
      const dcs = await orgRef.collection('locations').doc(locationId)
        .collection('daily_checklists').where('date', '==', date).get();

      for (const dc of dcs.docs) {
        const tasksSnap = await dc.ref.collection('tasks').get();
        const batch = db.batch();
        let batched = 0;
        for (const t of tasksSnap.docs) {
          total++;
          const data = t.data() || {};
          const patch = {};
          if (!data.taskName) patch.taskName = data.title || data.name || data.description || 'Task';
          if (typeof data.completed !== 'boolean') patch.completed = data.isComplete === true ? true : false;
          if (!data.checklistTemplateId && data.templateId) patch.checklistTemplateId = data.templateId;
          if (!data.templateTaskId) {
            const inferred = inferTemplateTaskId(t.id, data.templateId || data.checklistTemplateId);
            if (inferred) patch.templateTaskId = inferred;
          }
          if (Object.keys(patch).length > 0) {
            batch.set(t.ref, patch, { merge: true });
            batched++;
            updated++;
            if (batched >= 400) {
              await batch.commit();
              batched = 0;
            }
          }
        }
        if (batched > 0) await batch.commit();
      }
    }
  }

  console.log(`Normalized ${updated}/${total} tasks for ${date}.`);
}

run().catch(e => { console.error(e); process.exit(1); });
