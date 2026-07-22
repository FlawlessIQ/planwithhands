const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'plan-with-hands' });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function setOrgTimezone(orgId, timezone) {
  if (!orgId || !timezone) {
    console.log('Usage: node scripts/set_org_timezone.js <orgId> <IANA_timezone>');
    process.exit(1);
  }
  await db.collection('organizations').doc(orgId).set({
    timezone,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  // Also set on all locations if present
  const locs = await db.collection('organizations').doc(orgId).collection('locations').get();
  const batch = db.batch();
  locs.forEach(doc => batch.update(doc.ref, { timezone, updatedAt: admin.firestore.FieldValue.serverTimestamp() }));
  if (!locs.empty) await batch.commit();
  console.log(`Set org ${orgId} timezone -> ${timezone} (${locs.size} locations updated)`);
}

(async () => {
  const [orgId, timezone] = process.argv.slice(2);
  await setOrgTimezone(orgId, timezone);
  process.exit(0);
})();
