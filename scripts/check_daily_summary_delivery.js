// Verify recent notifications for the first admin in an org
// Usage: node scripts/check_daily_summary_delivery.js <ORG_ID>

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'plan-with-hands' });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function run(orgId) {
  console.log(`🔍 Checking recent notifications for org ${orgId}...`);

  const admins = await db
    .collection('users')
    .where('organizationId', '==', orgId)
    .where('userRole', 'in', [1, 2])
    .where('isActive', '==', true)
    .limit(1)
    .get();

  if (admins.empty) {
    console.log('❌ No admin/manager users found');
    return;
  }

  const adminDoc = admins.docs[0];
  const a = adminDoc.data() || {};
  console.log(`👤 Admin: ${a.firstName || ''} ${a.lastName || ''} (${adminDoc.id})`);

  const snap = await db
    .collection('userNotifications')
    .doc(adminDoc.id)
    .collection('notifications')
    .orderBy('createdAt', 'desc')
    .limit(10)
    .get();

  console.log(`🗂️  Found ${snap.size} recent notifications (showing up to 10)`);

  let foundDaily = 0;
  snap.forEach(doc => {
    const d = doc.data() || {};
    const t = d.createdAt?.toDate?.() || d.createdAt || null;
    const title = d.title || '(no title)';
    const type = d.type || '(no type)';
    const mark = type === 'daily_summary' ? '📋' : '📝';
    if (type === 'daily_summary') foundDaily++;
    console.log(` ${mark} ${t} - ${title} [${type}]`);
  });

  if (foundDaily === 0) {
    console.log('⚠️  No daily_summary notifications in the last 10 items.');
  } else {
    console.log(`✅ Found ${foundDaily} daily_summary notification(s) recently.`);
  }
}

(async () => {
  const orgId = process.argv[2];
  if (!orgId) {
    console.error('Usage: node scripts/check_daily_summary_delivery.js <ORG_ID>');
    process.exit(1);
  }
  try {
    await run(orgId);
  } catch (e) {
    console.error('❌ Error verifying notifications:', e);
    process.exit(1);
  }
  process.exit(0);
})();
