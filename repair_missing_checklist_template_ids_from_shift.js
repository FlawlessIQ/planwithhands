// Repair script: populate missing checklistTemplateIds on recent daily_checklists
// by reading the assigned shift.checklistTemplateIds and validating templates.

const {Firestore} = require('@google-cloud/firestore');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  try { admin.initializeApp(); } catch (_) {}
}

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function validateTemplates(orgRef, locationId, templateIds) {
  const valid = [];
  for (const templateId of Array.isArray(templateIds) ? templateIds : []) {
    try {
      const tRef = orgRef.collection('checklist_templates').doc(templateId);
      const tSnap = await tRef.get();
      if (!tSnap.exists) continue;
      const tData = tSnap.data() || {};
      const name = (tData.name || '').toString().trim();
      if (!name || name.toLowerCase() === 'unknown template') continue;
      const locIds = Array.isArray(tData.locationIds) ? tData.locationIds : [];
      if (locIds.length > 0 && !locIds.includes(locationId)) continue;
      valid.push(templateId);
    } catch (e) {
      // skip on error
    }
  }
  return [...new Set(valid)];
}

async function run() {
  const since = Date.now() - 10 * 24 * 60 * 60 * 1000; // last 10 days window
  const isoCutoff = new Date(since).toISOString().slice(0, 10);
  let checked = 0, updated = 0;

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

        // Pull from shift assignment
        const shiftId = data.shiftId;
        if (!shiftId) continue;
        const shiftSnap = await orgRef.collection('shifts').doc(shiftId).get();
        const shiftData = shiftSnap.exists ? (shiftSnap.data() || {}) : {};
        const assigned = Array.isArray(shiftData.checklistTemplateIds) ? shiftData.checklistTemplateIds : [];
        const valid = await validateTemplates(orgRef, locationId, assigned);
        if (valid.length > 0) {
          await dc.ref.set({ checklistTemplateIds: valid, updatedAt: admin.firestore.Timestamp.now() }, { merge: true });
          updated++;
          console.log(`✅ Repaired ${orgId}_${locationId}_${shiftId}_${data.date} with ${JSON.stringify(valid)}`);
        }
      }
    }
  }

  console.log(`Done. Checked ${checked}. Updated ${updated}.`);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
