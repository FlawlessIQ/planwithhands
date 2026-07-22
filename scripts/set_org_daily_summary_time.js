const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'plan-with-hands' });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function setOrgTime(orgId, hour, minute, enabled = true) {
  await db.collection('organizations').doc(orgId).set({
    dailySummarySettings: {
      enabled,
      hour,
      minute,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  }, { merge: true });
  console.log(`Set org ${orgId} dailySummarySettings -> ${enabled ? 'enabled' : 'disabled'} at ${String(hour).padStart(2,'0')}:${String(minute).padStart(2,'0')}`);
}

(async () => {
  const orgId = process.argv[2];
  const hour = parseInt(process.argv[3], 10);
  const minute = parseInt(process.argv[4], 10);
  const enabled = process.argv[5] !== 'false';
  if (!orgId || Number.isNaN(hour) || Number.isNaN(minute)) {
    console.log('Usage: node scripts/set_org_daily_summary_time.js <orgId> <hour> <minute> [enabled=true]');
    process.exit(1);
  }
  await setOrgTime(orgId, hour, minute, enabled);
  process.exit(0);
})();