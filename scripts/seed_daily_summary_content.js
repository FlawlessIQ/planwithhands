// Seed minimal content for today's daily summary so it won't be skipped
// Usage: node scripts/seed_daily_summary_content.js <ORG_ID>

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'plan-with-hands' });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

function todayStr() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, '0');
  const d = String(now.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

async function ensureLocation(orgId) {
  const locs = await db.collection('organizations').doc(orgId).collection('locations').limit(1).get();
  if (!locs.empty) {
    const doc = locs.docs[0];
    const data = doc.data() || {};
    return { id: doc.id, name: data.locationName || 'Unknown Location' };
  }

  // Create a lightweight test location if none exist
  const ref = db.collection('organizations').doc(orgId).collection('locations').doc();
  await ref.set({
    locationName: 'Test Location',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { id: ref.id, name: 'Test Location' };
}

async function seed(orgId) {
  const date = todayStr();
  const { id: locationId, name: locationName } = await ensureLocation(orgId);

  const shiftId = 'seed_shift';
  const templateId = 'seed_template';
  const checklistId = `${orgId}_${locationId}_${shiftId}_${templateId}_${date}`;

  const checklistRef = db.collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .doc(checklistId);

  // Create or update checklist shell
  await checklistRef.set({
    date,
    organizationId: orgId,
    locationId,
    shiftId,
    templateId,
    templateName: 'Seed Checklist',
    isCompleted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Add a few tasks via subcollection to ensure content is detected
  const tasksColl = checklistRef.collection('tasks');

  // 1) Completed task with notes
  await tasksColl.add({
    taskName: 'Seed: Clean tables',
    completed: true,
    isCompleted: true,
    notes: 'All tables sanitized.',
    completedByUserId: 'seed-user',
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    photoRequired: false,
  });

  // 2) Missed task with reason
  await tasksColl.add({
    taskName: 'Seed: Mop floor',
    completed: false,
    isCompleted: false,
    notCompletedReason: 'Short staffed today',
    photoRequired: false,
  });

  // 3) Completed task missing required photo (to trigger photoBypassed)
  await tasksColl.add({
    taskName: 'Seed: Fridge temperature log',
    completed: true,
    isCompleted: true,
    photoRequired: true,
    // no photo fields on purpose
    completedByUserId: 'seed-user',
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`✅ Seeded summary content for ${orgId} at ${locationName} (${locationId}) for ${date}`);
}

(async () => {
  const orgId = process.argv[2];
  if (!orgId) {
    console.error('Usage: node scripts/seed_daily_summary_content.js <ORG_ID>');
    process.exit(1);
  }
  try {
    await seed(orgId);
  } catch (e) {
    console.error('❌ Failed to seed content:', e);
    process.exit(1);
  }
  process.exit(0);
})();
