// Cleanup script: delete recent daily_checklists that have no checklistTemplateIds
// and their tasks subcollections, in the planwithhands database.

const {Firestore} = require('@google-cloud/firestore');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  try { admin.initializeApp(); } catch (_) {}
}

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function deleteCollection(ref) {
  const batchSize = 400;
  while (true) {
    const snap = await ref.limit(batchSize).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function run() {
  const since = Date.now() - 10 * 24 * 60 * 60 * 1000; // last 10 days
  const isoCutoff = new Date(since).toISOString().slice(0, 10);
  let checked = 0, deleted = 0;

  const orgs = await db.collection('organizations').get();
  for (const orgDoc of orgs.docs) {
    const orgId = orgDoc.id;
    const orgRef = db.collection('organizations').doc(orgId);
    const locs = await orgRef.collection('locations').get();
    for (const loc of locs.docs) {
      const locationId = loc.id;
      const dcs = await orgRef.collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '>=', isoCutoff)
        .get();

      for (const dc of dcs.docs) {
        const data = dc.data() || {};
        checked++;
        const hasIds = Array.isArray(data.checklistTemplateIds) && data.checklistTemplateIds.length > 0;
        if (hasIds) continue;
        // Delete tasks subcollection
        await deleteCollection(dc.ref.collection('tasks'));
        // Delete checklist doc
        await dc.ref.delete();
        deleted++;
        console.log(`🗑️ Deleted ${orgId}_${locationId}_${data.shiftId || 'shift'}_${data.date}`);
      }
    }
  }

  console.log(`Done. Checked ${checked}. Deleted ${deleted}.`);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
