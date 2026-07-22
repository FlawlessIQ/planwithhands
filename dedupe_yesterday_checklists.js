#!/usr/bin/env node

/**
 * Dedupe daily_checklists documents for a given date by (templateId, shiftId) within an org/location.
 * For groups with >1 checklist, pick a canonical (earliest createdAt or smallest id),
 * then:
 *  - If extras have only duplicate tasks (by key), delete the extra checklist.
 *  - If extras have unique tasks, optionally move those tasks to canonical (preserving doc ids),
 *    then delete the extra checklist.
 *
 * Safety / Flags:
 *  --dry-run: do not write anything
 *  --date=YYYY-MM-DD: target date (default: yesterday UTC)
 *  --org=ORG_ID, --location=LOC_ID: scope
 *  --verbose or -v: detailed logging
 *  --move-unique: when extras contain unique tasks, move them to the canonical before deletion
 */

const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { dryRun: false, date: null, org: null, location: null, verbose: false, moveUnique: false };
  for (const a of args) {
    if (a === '--dry-run') out.dryRun = true;
    else if (a === '--verbose' || a === '-v') out.verbose = true;
    else if (a.startsWith('--date=')) out.date = a.split('=')[1];
    else if (a.startsWith('--org=')) out.org = a.split('=')[1];
    else if (a.startsWith('--location=')) out.location = a.split('=')[1];
    else if (a === '--move-unique') out.moveUnique = true;
  }
  return out;
}

function isoYesterday() {
  const now = new Date();
  now.setUTCDate(now.getUTCDate() - 1);
  return now.toISOString().split('T')[0];
}

function normalize(str) {
  return (str || '').toString().trim().toLowerCase();
}

function taskKey(data) {
  if (data.isCarryForward) {
    return `cf|${data.originalChecklistId || ''}|${data.originalTaskId || ''}`;
  }
  const name = normalize(data.taskName || data.name || data.title || data.description || '');
  const templateName = normalize(
    data.templateName || (Array.isArray(data.templateNames) ? data.templateNames[0] : data.templateNames) || ''
  );
  const section = normalize(data.sectionName || data.section || data.groupName || data.area || data.category || '');
  const photoBool = !!(data.photoRequired || data.requiresPhoto || data.requirePhoto || data.needsPhoto || data.isPhotoRequired);
  return `ag|${name}|${templateName}|${section}|${photoBool ? '1' : '0'}`;
}

async function getChecklistTasksMap(clRef) {
  const snap = await clRef.collection('tasks').get();
  const map = new Map();
  for (const doc of snap.docs) {
    const k = taskKey(doc.data());
    if (!map.has(k)) map.set(k, []);
    map.get(k).push(doc);
  }
  return { snap, map };
}

function chooseCanonical(checklists) {
  // choose earliest createdAt, else smallest ID
  let best = null;
  for (const cl of checklists) {
    const createdAt = cl.get('createdAt')?.toDate?.() || new Date(0);
    if (!best) best = { cl, ts: createdAt };
    else if (createdAt < best.ts || (createdAt.getTime?.() === best.ts.getTime?.() && cl.id < best.cl.id)) {
      best = { cl, ts: createdAt };
    }
  }
  return best.cl;
}

async function processGroup({ orgId, locId, targetDate, group, dryRun, verbose, moveUnique }) {
  const canonical = chooseCanonical(group);
  const others = group.filter(d => d.id !== canonical.id);
  const canonicalRef = canonical.ref;
  const { map: canonMap } = await getChecklistTasksMap(canonicalRef);
  let totalDeletedChecklists = 0;
  let movedTasks = 0;
  let deletedTasks = 0;

  for (const extra of others) {
    const extraRef = extra.ref;
    const { snap: extraSnap, map: extraMap } = await getChecklistTasksMap(extraRef);
    // Determine unique tasks in extra vs canonical
    const uniqueDocs = [];
    for (const [k, docs] of extraMap.entries()) {
      if (!canonMap.has(k)) {
        for (const d of docs) uniqueDocs.push(d);
      }
    }

    if (uniqueDocs.length === 0) {
      if (!dryRun) {
        // delete the extra checklist entirely (tasks subcollection will be deleted recursively only via client; here batch delete tasks then delete doc)
        for (let i = 0; i < extraSnap.size; i += 400) {
          const batch = db.batch();
          extraSnap.docs.slice(i, i + 400).forEach(d => batch.delete(extraRef.collection('tasks').doc(d.id)));
          await batch.commit();
        }
        await extraRef.delete();
      }
      totalDeletedChecklists += 1;
      if (verbose) console.log(`   🗑️  Deleted duplicate checklist ${orgId}/${locId}/${extra.id} (no unique tasks)`);
      continue;
    }

    if (moveUnique) {
      if (!dryRun) {
        // move unique tasks to canonical (preserve doc ids)
        for (let i = 0; i < uniqueDocs.length; i += 200) {
          const batch = db.batch();
          const chunk = uniqueDocs.slice(i, i + 200);
          for (const d of chunk) {
            batch.set(canonicalRef.collection('tasks').doc(d.id), d.data(), { merge: true });
            batch.delete(d.ref);
          }
          await batch.commit();
        }
        // after moving, delete any remaining tasks in extra and the extra checklist doc
        const remaining = await extraRef.collection('tasks').get();
        for (let i = 0; i < remaining.size; i += 400) {
          const batch = db.batch();
          remaining.docs.slice(i, i + 400).forEach(d => batch.delete(extraRef.collection('tasks').doc(d.id)));
          await batch.commit();
        }
        await extraRef.delete();
      }
      movedTasks += uniqueDocs.length;
      totalDeletedChecklists += 1;
      if (verbose) console.log(`   🔁 Moved ${uniqueDocs.length} tasks and deleted checklist ${orgId}/${locId}/${extra.id}`);
    } else {
      if (verbose) console.log(`   ⚠️  Checklist ${extra.id} has ${uniqueDocs.length} unique tasks; use --move-unique to merge+delete`);
    }
  }

  // Update canonical counters
  if (!dryRun) {
    const after = await canonicalRef.collection('tasks').get();
    let completed = 0;
    for (const d of after.docs) {
      const m = d.data();
      if (m.completed === true || m.isCompleted === true) completed++;
    }
    await canonicalRef.set(
      {
        totalItems: after.size,
        completedItems: completed,
        isCompleted: after.size > 0 && completed === after.size,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  return { totalDeletedChecklists, movedTasks, deletedTasks };
}

async function run() {
  const args = parseArgs();
  const targetDate = args.date || isoYesterday();
  console.log(`🔎 Dedupe daily_checklists for ${targetDate} ${args.dryRun ? '(DRY RUN)' : ''}`);

  const orgs = await db.collection('organizations').get();
  let deletedChecklists = 0;
  let moved = 0;

  for (const org of orgs.docs) {
    const orgId = org.id;
    if (args.org && orgId !== args.org) continue;
    console.log(`\n🏢 Org ${orgId}`);
    const locs = await db.collection('organizations').doc(orgId).collection('locations').get();
    for (const loc of locs.docs) {
      const locId = loc.id;
      if (args.location && locId !== args.location) continue;
      const cls = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locId)
        .collection('daily_checklists')
        .where('date', '==', targetDate)
        .get();

      // group by (templateId, shiftId)
      const groups = new Map();
      for (const cl of cls.docs) {
        const k = `${cl.get('templateId') || ''}|${cl.get('shiftId') || ''}`;
        if (!groups.has(k)) groups.set(k, []);
        groups.get(k).push(cl);
      }

      for (const [k, arr] of groups.entries()) {
        if (arr.length <= 1) continue;
        if (args.verbose) console.log(`   ➕ Group ${k} has ${arr.length} checklists`);
        const res = await processGroup({ orgId, locId, targetDate, group: arr, dryRun: args.dryRun, verbose: args.verbose, moveUnique: args.moveUnique });
        deletedChecklists += res.totalDeletedChecklists;
        moved += res.movedTasks;
      }
    }
  }

  console.log(`\n✅ Done. Deleted duplicate checklists: ${deletedChecklists}${moved ? `, moved tasks: ${moved}` : ''}`);
}

run().then(() => process.exit(0)).catch(err => {
  console.error('❌ Dedupe failed', err);
  process.exit(1);
});
