#!/usr/bin/env node

/**
 * Dedupe yesterday's (or specified date's) daily_checklists tasks across organizations.
 * Safety features:
 *  - --dry-run: does NOT delete or update, only reports what would change
 *  - --date=YYYY-MM-DD: target a specific date (default: yesterday in UTC)
 *  - --org=ORG_ID: limit to one organization
 *  - --location=LOC_ID: limit to one location (requires matching org)
 *  - --verbose: print every checklist processed, even with 0 deletions
 *  - --aggressive-name-dedupe: also dedupe by normalized name + templateName + section + photoRequired
 * Keys:
 *  - Carry-forward: cf|originalChecklistId|originalTaskId
 *  - Template tasks: tpl|templateTaskId (fallback: tpl|name:<lowercased-name>)
 * Keeps the earliest createdAt (or, on tie/missing, the smallest doc id) and deletes others.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { dryRun: false, date: null, org: null, location: null, verbose: false, aggressive: false };
  for (const a of args) {
    if (a === '--dry-run') out.dryRun = true;
    else if (a === '--verbose' || a === '-v') out.verbose = true;
    else if (a.startsWith('--date=')) out.date = a.split('=')[1];
    else if (a.startsWith('--org=')) out.org = a.split('=')[1];
    else if (a.startsWith('--location=')) out.location = a.split('=')[1];
    else if (a === '--aggressive-name-dedupe' || a === '--aggressive') out.aggressive = true;
  }
  return out;
}

function normalize(str) {
  return (str || '').toString().trim().toLowerCase().replace(/\s+/g, ' ');
}

function keyForTask(data, { aggressive }) {
  if (data.isCarryForward) {
    if (aggressive) {
      const nameKey = normalize(data.taskName || data.name || data.title || data.description || '');
      const templateName = normalize(
        data.templateName || (Array.isArray(data.templateNames) ? data.templateNames[0] : data.templateNames) || ''
      );
      const section = normalize(
        data.sectionName || data.section || data.groupName || data.area || data.category || ''
      );
      const photoBool = !!(data.photoRequired || data.requiresPhoto || data.requirePhoto || data.needsPhoto || data.isPhotoRequired);
      return `ag|${nameKey}|${templateName}|${section}|${photoBool ? '1' : '0'}`;
    }
    const oc = (data.originalChecklistId || '').toString();
    const ot = (data.originalTaskId || '').toString();
    return `cf|${oc}|${ot}`;
  }
  let tmpl = (data.templateTaskId || '').toString().trim();
  if (!tmpl) {
    const name = normalize(data.taskName || data.name || data.title || data.description || '');
    tmpl = `name:${name}`;
  }
  if (aggressive) {
    const nameKey = normalize(data.taskName || data.name || data.title || data.description || '');
    const templateName = normalize(
      data.templateName || (Array.isArray(data.templateNames) ? data.templateNames[0] : data.templateNames) || ''
    );
    const section = normalize(
      data.sectionName || data.section || data.groupName || data.area || data.category || ''
    );
    const photoBool = !!(data.photoRequired || data.requiresPhoto || data.requirePhoto || data.needsPhoto || data.isPhotoRequired);
    return `ag|${nameKey}|${templateName}|${section}|${photoBool ? '1' : '0'}`;
  }
  return `tpl|${tmpl}`;
}

async function dedupeChecklistTasks(clRef, { dryRun, aggressive }) {
  const tasksSnap = await clRef.collection('tasks').get();
  if (tasksSnap.empty) return { deleted: 0, kept: 0 };
  const keep = new Map();
  const toDelete = [];
  const byKey = new Map();
  for (const doc of tasksSnap.docs) {
    const data = doc.data();
    const key = keyForTask(data, { aggressive });
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push(doc);
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
  if (!dryRun) {
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
  } else {
    deleted = toDelete.length;
  }
  // collect duplicate keys for reporting
  const duplicateKeys = [];
  for (const [k, arr] of byKey.entries()) {
    if (arr.length > 1) duplicateKeys.push({ key: k, count: arr.length });
  }
  return { deleted, kept: keep.size, duplicateKeys };
}

function isoYesterday() {
  const now = new Date();
  now.setUTCDate(now.getUTCDate() - 1);
  return now.toISOString().split('T')[0];
}

async function dedupeForDate({ targetDate, org: orgFilter, location: locFilter, dryRun, verbose, aggressive }) {
  console.log(`🔎 Dedupe tasks for ${targetDate} ${dryRun ? '(DRY RUN)' : ''}`);
  const orgs = await db.collection('organizations').get();
  let totalDeleted = 0;
  for (const org of orgs.docs) {
    const orgId = org.id;
    if (orgFilter && orgId !== orgFilter) continue;
    console.log(`\n🏢 Org ${orgId}`);
    const locs = await db.collection('organizations').doc(orgId).collection('locations').get();
    for (const loc of locs.docs) {
      const locId = loc.id;
      if (locFilter && locId !== locFilter) continue;
      const cls = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locId)
        .collection('daily_checklists')
        .where('date', '==', targetDate)
        .get();
      for (const cl of cls.docs) {
        const res = await dedupeChecklistTasks(cl.ref, { dryRun, aggressive });
        if (res.deleted > 0 || verbose) {
          console.log(`   ${res.deleted > 0 ? '✂️ ' : '• '} ${orgId}/${locId}/${cl.id} ${dryRun ? 'would delete' : 'deleted'} ${res.deleted} duplicates, kept ${res.kept}${aggressive ? ' [aggressive]' : ''}`);
          if ((res.duplicateKeys?.length || 0) > 0 && (verbose || dryRun)) {
            for (const dk of res.duplicateKeys) {
              console.log(`      ↳ dup key ${dk.key} x${dk.count}`);
            }
          }
        }
        totalDeleted += res.deleted;
      }
    }
  }
  console.log(`\n✅ Done. Total duplicates ${dryRun ? 'to remove' : 'removed'}: ${totalDeleted}`);
}

function main() {
  const args = parseArgs();
  const targetDate = args.date || isoYesterday();
  return dedupeForDate({ targetDate, org: args.org, location: args.location, dryRun: args.dryRun, verbose: args.verbose, aggressive: args.aggressive });
}

main().then(() => process.exit(0)).catch(err => {
  console.error('❌ Dedupe failed', err);
  process.exit(1);
});
