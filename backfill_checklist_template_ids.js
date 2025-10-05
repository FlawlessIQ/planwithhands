#!/usr/bin/env node

/**
 * Backfill checklistTemplateIds on daily_checklists by inspecting tasks subcollection.
 * Scope: last 7 days, all orgs/locations in database 'planwithhands'.
 */
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function backfill() {
  const orgs = await db.collection('organizations').get();
  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);
  const weekAgoString = weekAgo.toISOString().split('T')[0];

  let updated = 0, checked = 0;

  for (const orgDoc of orgs.docs) {
    const orgId = orgDoc.id;
    const locs = await db.collection('organizations').doc(orgId).collection('locations').get();
    for (const loc of locs.docs) {
      const locationId = loc.id;
      const checklists = await db.collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '>=', weekAgoString)
        .get();

      for (const cl of checklists.docs) {
        checked++;
        const data = cl.data() || {};
        const current = Array.isArray(data.checklistTemplateIds) ? data.checklistTemplateIds : [];
        if (current.length > 0) continue;

        // derive from tasks
        const tasksSnap = await cl.ref.collection('tasks').limit(500).get();
        const templates = new Set();
        for (const t of tasksSnap.docs) {
          const td = t.data() || {};
          const tid = td.checklistTemplateId || td.templateId || null;
          if (tid) templates.add(String(tid));
        }
        const derived = Array.from(templates);
        if (derived.length === 0) continue;

        try {
          await cl.ref.set({ checklistTemplateIds: derived }, { merge: true });
          updated++;
          console.log(`✅ Backfilled ${cl.id} with ${JSON.stringify(derived)}`);
        } catch (e) {
          console.error(`❌ Failed to backfill ${cl.id}`, e.message);
        }
      }
    }
  }

  console.log(`\nDone. Checked ${checked} checklists. Updated ${updated}.`);
}

backfill().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });
