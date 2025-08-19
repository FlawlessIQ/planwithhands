const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

if (!admin.apps.length) {
  admin.initializeApp();
}

// Select Firestore database id from env; default to '(default)'
const DB_ID = process.env.FIRESTORE_DB_ID || '(default)';
const db = getFirestore(admin.app(), DB_ID);

async function hasTasksSubcollection(docRef) {
  const snap = await docRef.collection('tasks').limit(1).get();
  return !snap.empty;
}

function isArrayWithItems(v) {
  return Array.isArray(v) && v.length > 0;
}

/**
 * Migrates checklist_templates.tasks[] (array) into subcollection /tasks.
 * Idempotent: skips if subcollection exists or migratedTasks === true.
 * Use: GET .../migrateChecklistTemplates?dryRun=true (default) or false
 */
exports.migrateChecklistTemplates = functions.https.onRequest(async (req, res) => {
  try {
    const dryRun = (req.query.dryRun ?? 'true') !== 'false'; // default true
    const diag = String(req.query.diag ?? '0') === '1';
    const orgId = req.query.orgId ? String(req.query.orgId) : null;
    const limit = req.query.limit ? Math.max(1, parseInt(String(req.query.limit), 10) || 0) : 0;
    const batchLimit = 400;

    let pendingWrites = 0;
    let batch = db.batch();
    const batches = [];

    let templatesTotal = 0;
    let templatesWithArray = 0;
    let templatesAlreadyMigrated = 0;
    let templatesEligible = 0;

    let migrated = 0;
    let skipped = 0;

    // Build orgRefs list honoring orgId and limit
    let orgRefs = [];
    if (orgId) {
      const ref = db.collection('organizations').doc(orgId);
      const doc = await ref.get();
      if (doc.exists) orgRefs.push(ref);
    } else {
      const orgSnap = await db.collection('organizations').get();
      orgRefs = orgSnap.docs.map(d => d.ref);
      if (limit && orgRefs.length > limit) orgRefs = orgRefs.slice(0, limit);
    }

    const orgDiags = [];
    const candidates = []; // { docRef, data }

    // Gather diagnostics and build candidate list
    for (const oref of orgRefs) {
      const tplSnap = await oref.collection('checklist_templates').get();
      let total = tplSnap.size, withArray = 0, already = 0, eligible = 0;
      const examples = [];
      for (const tpl of tplSnap.docs) {
        const data = tpl.data() || {};
        const hasArray = isArrayWithItems(data.tasks);
        const hasSub = await hasTasksSubcollection(tpl.ref);
        const migratedFlag = data.migratedTasks === true;

        templatesTotal++;
        if (hasArray) withArray++;
        if (hasSub || migratedFlag) {
          already++;
        } else if (hasArray) {
          eligible++;
          candidates.push({ docRef: tpl.ref, data });
          if (examples.length < 3) examples.push(tpl.ref.path);
        }
      }
      templatesWithArray += withArray;
      templatesAlreadyMigrated += already;
      templatesEligible += eligible;
      orgDiags.push({ orgId: oref.id, total, withArray, alreadyMigrated: already, eligible, examples });
    }

    // Migration loop: iterate candidates and perform same write logic as before
    for (const candidate of candidates) {
      const docRef = candidate.docRef;
      const data = candidate.data || {};
      const arr = Array.isArray(data.tasks) ? data.tasks : null;

      // Double-check subcollection (skip if it appeared in the meantime)
      const hasSubNow = await hasTasksSubcollection(docRef);
      if (!arr || arr.length === 0 || hasSubNow || data.migratedTasks === true) {
        skipped++;
        continue;
      }

      arr.forEach((item, idx) => {
        const o = (typeof item === 'string') ? { title: item } : (item || {});
        const title = String(o.title ?? `Task ${idx + 1}`);
        const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').slice(0, 32) || `task-${idx + 1}`;
        const id = `${String(idx).padStart(3, '0')}-${slug}`;
        const ref = docRef.collection('tasks').doc(id);

        const payload = {
          title,
          description: o.description ?? o.notes ?? null,
          photoRequired: !!o.photoRequired,
          required: (typeof o.required === 'boolean') ? o.required : true,
          order: idx,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (!dryRun) {
          batch.set(ref, payload, { merge: true });
          pendingWrites++;
          if (pendingWrites >= batchLimit) {
            batches.push(batch);
            batch = db.batch();
            pendingWrites = 0;
          }
        }
      });

      if (!dryRun) {
        batch.set(docRef, {
          tasksCount: arr.length,
          migratedTasks: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          tasks: admin.firestore.FieldValue.delete(),
        }, { merge: true });
        pendingWrites++;
        if (pendingWrites >= batchLimit) {
          batches.push(batch);
          batch = db.batch();
          pendingWrites = 0;
        }
      }

      migrated++;
    }

    if (!dryRun && (pendingWrites > 0 || batches.length > 0)) {
      batches.push(batch);
      for (const b of batches) {
        await b.commit();
      }
    }

    return res.json({
      dryRun,
      databaseId: DB_ID,
      orgsScanned: orgRefs.length,
      templatesScanned: templatesTotal,
      templatesWithArray,
      templatesAlreadyMigrated,
      templatesEligible,
      templatesMigrated: migrated,
      templatesSkipped: skipped,
      batchesCommitted: dryRun ? 0 : batches.length,
      orgs: diag ? orgDiags : undefined,
    });
  } catch (err) {
    console.error('[migrateChecklistTemplates] error', err);
    return res.status(500).json({ error: String(err) });
  }
});
