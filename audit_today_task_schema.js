// Audit today's tasks across all orgs/locations/checklists for missing fields that cause Unknown Template in UI.
// Checks taskName, completed, checklistTemplateId; reports counts by org.

const {Firestore} = require('@google-cloud/firestore');
const admin = require('firebase-admin');
if (!admin.apps.length) { try { admin.initializeApp(); } catch (_) {} }

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

function todayISO(tz) {
  return new Date().toISOString().slice(0,10);
}

async function run() {
  const date = todayISO();
  const results = [];
  const orgs = await db.collection('organizations').get();
  for (const orgDoc of orgs.docs) {
    const orgId = orgDoc.id;
    const orgRef = db.collection('organizations').doc(orgId);
    const locs = await orgRef.collection('locations').get();
    let checked = 0, bad = 0;

    for (const loc of locs.docs) {
      const locationId = loc.id;
      const dcs = await orgRef.collection('locations').doc(locationId)
        .collection('daily_checklists').where('date', '==', date).get();
      for (const dc of dcs.docs) {
        const tasksSnap = await dc.ref.collection('tasks').get();
        for (const t of tasksSnap.docs) {
          checked++;
          const data = t.data() || {};
          const ok = !!data.taskName && typeof data.completed === 'boolean' && !!(data.checklistTemplateId || data.templateId);
          if (!ok) bad++;
        }
      }
    }
    results.push({ orgId, checked, bad });
  }
  console.log('Audit for today:', date);
  for (const r of results) {
    console.log(`Org ${r.orgId}: checked ${r.checked}, bad ${r.bad}`);
  }
}

run().catch(e => { console.error(e); process.exit(1); });
