const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'plan-with-hands' });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function run() {
  console.log('🔎 Checking recipients for daily summary...');
  const snap = await db
    .collection('users')
    .where('userRole', 'in', [1, 2])
    .where('isActive', '==', true)
    .get();

  console.log(`Found ${snap.size} active manager/admin users`);

  const byOrg = new Map();
  snap.forEach(doc => {
    const d = doc.data();
    const orgId = d.organizationId || '(no org)';
    if (!byOrg.has(orgId)) byOrg.set(orgId, []);
    byOrg.get(orgId).push({ id: doc.id, name: `${d.firstName || ''} ${d.lastName || ''}`.trim() || 'Unnamed', role: d.userRole });
  });

  for (const [orgId, users] of byOrg.entries()) {
    console.log(`\nOrg ${orgId}: ${users.length} recipient(s)`);
    users.forEach(u => console.log(` - ${u.name} (${u.id}) role=${u.role}`));
  }

  console.log('\n✅ Recipient scan complete');
}

run().catch(e => { console.error(e); process.exit(1); });