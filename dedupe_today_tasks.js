#!/usr/bin/env node

/**
 * Dedupe today's daily_checklists tasks across all organizations.
 * Keys:
 *  - Carry-forward: cf|originalChecklistId|originalTaskId
 *  - Template tasks: tpl|templateTaskId (fallback: tpl|name:<lowercased-name>)
 * Keeps the earliest createdAt (or smallest doc id) and deletes others.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

function keyForTask(data) {
  if (data.isCarryForward) {
    const oc = (data.originalChecklistId || '').toString();
    const ot = (data.originalTaskId || '').toString();
    return `cf|${oc}|${ot}`;
  }
  let tmpl = (data.templateTaskId || '').toString().trim();
  if (!tmpl) {
    const name = (data.taskName || data.name || data.title || data.description || '')
      .toString()
      .trim()
      .toLowerCase();
    tmpl = `name:${name}`;
  }
  return `tpl|${tmpl}`;
}

async function dedupeChecklistTasks(clRef) {
  const tasksSnap = await clRef.collection('tasks').get();
  if (tasksSnap.empty) return { deleted: 0, kept: 0 };
  const keep = new Map();
  const toDelete = [];
  for (const doc of tasksSnap.docs) {
    const data = doc.data();
    const key = keyForTask(data);
    if (!keep.has(key)) {
      keep.set(key, doc);
    } else {
      const prev = keep.get(key);
      const prevTs = prev.get('createdAt')?.toDate?.() || new Date(0);
      const curTs = data.createdAt?.toDate?.() || new Date(0);
      const replace = curTs < prevTs || (curTs.getTime?.() === prevTs.getTime?.() && doc.id < prev.id);
      if (replace) {
        toDelete.push(prev);
        keep.set(key, doc);
      } else {
        toDelete.push(doc);
      }
    }
  }
  let deleted = 0;
  for (let i = 0; i < toDelete.length; i += 400) {
    const batch = db.batch();
    const chunk = toDelete.slice(i, i + 400);
    chunk.forEach(d => batch.delete(d.ref));
    await batch.commit();
    deleted += chunk.length;
  }
  // update parent counters
  const afterSnap = await clRef.collection('tasks').get();
  let completed = 0;
  afterSnap.forEach(d => {
    const m = d.data();
    if (m.completed === true || m.isCompleted === true) completed++;
  });
  await clRef.set(
    {
      totalItems: afterSnap.size,
      completedItems: completed,
      isCompleted: afterSnap.size > 0 && completed === afterSnap.size,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return { deleted, kept: keep.size };
}

async function dedupeToday() {
  const today = new Date().toISOString().split('T')[0];
  console.log(`🔎 Dedupe tasks for ${today}`);
  const orgs = await db.collection('organizations').get();
  let totalDeleted = 0;
  for (const org of orgs.docs) {
    const orgId = org.id;
    console.log(`\n🏢 Org ${orgId}`);
    const locs = await db.collection('organizations').doc(orgId).collection('locations').get();
    for (const loc of locs.docs) {
      const locId = loc.id;
      const cls = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locId)
        .collection('daily_checklists')
        .where('date', '==', today)
        .get();
      for (const cl of cls.docs) {
        const res = await dedupeChecklistTasks(cl.ref);
        if (res.deleted > 0) {
          console.log(`   ✂️  ${orgId}/${locId}/${cl.id} deleted ${res.deleted} duplicates, kept ${res.kept}`);
        }
        totalDeleted += res.deleted;
      }
    }
  }
  console.log(`\n✅ Done. Total duplicates removed: ${totalDeleted}`);
}

dedupeToday().then(() => process.exit(0)).catch(err => {
  console.error('❌ Dedupe failed', err);
  process.exit(1);
});
