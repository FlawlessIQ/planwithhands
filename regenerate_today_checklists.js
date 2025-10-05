#!/usr/bin/env node

/**
 * CAUTION: Deletes ALL today's daily_checklists per org/location and their tasks,
 * then relies on app/CF generator to recreate idempotently. Use when duplication is severe.
 */

const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function deleteTodayForOrg(orgId, today) {
  let deletedChecklists = 0;
  let deletedTasks = 0;
  const locs = await db.collection('organizations').doc(orgId).collection('locations').get();
  for (const loc of locs.docs) {
    const locId = loc.id;
    const cls = await db.collection('organizations').doc(orgId)
      .collection('locations').doc(locId)
      .collection('daily_checklists')
      .where('date', '==', today)
      .get();
    for (const cl of cls.docs) {
      const tasksSnap = await cl.ref.collection('tasks').get();
      if (!tasksSnap.empty) {
        for (let i = 0; i < tasksSnap.docs.length; i += 400) {
          const chunk = tasksSnap.docs.slice(i, i + 400);
          const batch = db.batch();
          chunk.forEach(d => batch.delete(d.ref));
          await batch.commit();
          deletedTasks += chunk.length;
        }
      }
      await cl.ref.delete();
      deletedChecklists++;
      console.log(`   🗑️ Deleted ${orgId}/${locId}/${cl.id} (tasks ${tasksSnap.size})`);
    }
  }
  return { deletedChecklists, deletedTasks };
}

async function run() {
  const today = new Date().toISOString().split('T')[0];
  console.log(`♻️ Regenerate: Delete all today's checklists (${today})`);
  const orgs = await db.collection('organizations').get();
  let totalCls = 0, totalTasks = 0;
  for (const org of orgs.docs) {
    const orgId = org.id;
    console.log(`\n🏢 Org ${orgId}`);
    const res = await deleteTodayForOrg(orgId, today);
    totalCls += res.deletedChecklists;
    totalTasks += res.deletedTasks;
    console.log(`   Summary org ${orgId}: checklists ${res.deletedChecklists}, tasks ${res.deletedTasks}`);
  }
  console.log(`\n✅ Deleted today: checklists ${totalCls}, tasks ${totalTasks}`);
  console.log(`ℹ️ App/CF generator is idempotent and will recreate checklists on next ensure/generator run.`);
}

run().then(() => process.exit(0)).catch(err => { console.error('❌ Failed', err); process.exit(1); });
