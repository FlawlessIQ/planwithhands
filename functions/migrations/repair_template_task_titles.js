const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

if (!admin.apps.length) admin.initializeApp();
const DB_ID = process.env.FIRESTORE_DB_ID || "(default)";
const db = getFirestore(admin.app(), DB_ID);

const DEFAULT_LIMIT = 200;
const DEFAULT_DAYS = 365;
const CONCURRENCY = 5;

function firstNonEmptyTitle(d) {
  if (!d) return null;
  return (d.title && String(d.title).trim()) || (d.name && String(d.name).trim()) || (d.task && String(d.task).trim()) || (d.label && String(d.label).trim()) || null;
}

function determineOrder(d, docId) {
  if (!d && !docId) return null;
  const candidates = [d && d.order, d && d.index, d && d.position, d && d.sort];
  for (const c of candidates) {
    if (c !== undefined && c !== null && c !== "") {
      const n = parseInt(c, 10);
      if (!Number.isNaN(n)) return n;
    }
  }
  if (docId) {
    const m1 = docId.match(/(\d+)$/);
    if (m1) return parseInt(m1[1], 10);
    const m2 = docId.match(/task[_-]?(\d+)$/i);
    if (m2) return parseInt(m2[1], 10);
  }
  return null;
}

function isDefaultTitle(title) {
  if (!title || title === null) return false;
  return /^Task\s+\d+$/i.test(title);
}

// Simple concurrency pool
async function mapWithConcurrency(items, limit, fn) {
  const results = [];
  let i = 0;
  const workers = new Array(limit).fill(0).map(async () => {
    while (i < items.length) {
      const idx = i++;
      try {
        results[idx] = await fn(items[idx], idx);
      } catch (e) {
        results[idx] = {error: e};
      }
    }
  });
  await Promise.all(workers);
  return results;
}

async function tryA1(templateId, orgId, before) {
  // Attempt collectionGroup query for most recent checklist for this template
  try {
    let q = db.collectionGroup("daily_checklists");
    if (templateId) q = q.where("templateId", "==", templateId);
    if (orgId) q = q.where("orgId", "==", orgId);
    if (before) {
      const beforeDate = new Date(before);
      if (!Number.isNaN(beforeDate.getTime())) q = q.where("createdAt", "<=", beforeDate);
    }
    // keep ordering consistent with composite index: templateId ASC, createdAt DESC
    // include a templateId orderBy even if equality is used to match index
    q = q.orderBy("templateId").orderBy("createdAt", "desc").limit(1);
    const snap = await q.get();
    if (!snap.empty) return {doc: snap.docs[0], source: "A1"};
    return null;
  } catch (err) {
    const msg = String(err);
    const indexMatch = msg.match(/https:\/\/console\.firebase\.google\.com\/[\S]+indexes\?create_composite=[^\s]+/);
    return {error: err, indexLink: indexMatch ? indexMatch[0] : null};
  }
}

async function tryA2(templateId, orgId, days) {
  // Scan collectionGroup in a bounded window (client-side filter)
  const scanLimit = 2000; // per attempt
  const cutoff = Date.now() - days * 24 * 3600 * 1000;
  const q = db.collectionGroup("daily_checklists").limit(scanLimit);
  const snap = await q.get();
  if (snap.empty) return null;
  for (const doc of snap.docs) {
    const d = doc.data();
    if (!d) continue;
    const createdAt = d.createdAt && d.createdAt._seconds ? d.createdAt._seconds * 1000 : (typeof d.createdAt === "string" ? Date.parse(d.createdAt) : null);
    if (createdAt && createdAt < cutoff) continue;
    const tid = d.templateId || d.templateID || (d.template && d.template.id) || null;
    const oid = d.orgId || d.organizationId || null;
    if (templateId === tid && (!orgId || orgId === oid)) return {doc, source: "A2"};
  }
  return null;
}

async function tryA3(templateId, orgId, days, maxPages = 5) {
  // Paginate collectionGroup to find any older checklist matching templateId
  const pageSize = 2000;
  let pageToken = null;
  const cutoff = Date.now() - days * 24 * 3600 * 1000;
  for (let page = 0; page < maxPages; page++) {
    let q = db.collectionGroup("daily_checklists").limit(pageSize);
    if (pageToken) q = q.startAfter(pageToken);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      const d = doc.data();
      if (!d) continue;
      const createdAt = d.createdAt && d.createdAt._seconds ? d.createdAt._seconds * 1000 : (typeof d.createdAt === "string" ? Date.parse(d.createdAt) : null);
      if (createdAt && createdAt < cutoff) continue;
      const tid = d.templateId || d.templateID || (d.template && d.template.id) || null;
      const oid = d.orgId || d.organizationId || null;
      if (templateId === tid && (!orgId || orgId === oid)) return {doc, source: "A3"};
    }
    pageToken = snap.docs[snap.docs.length - 1];
  }
  return null;
}

exports.repairTemplateTaskTitles = functions.runWith({timeoutSeconds: 300, memory: "512MB"}).https.onRequest(async (req, res) => {
  try {
    const orgId = req.query.orgId;
    const templateIdQuery = req.query.templateId;
    const limit = parseInt(req.query.limit || DEFAULT_LIMIT, 10);
    const dryRun = (req.query.dryRun || "true") === "true";
    const diag = req.query.diag === "1";
    const days = parseInt(req.query.days || DEFAULT_DAYS, 10);

    let orgs = [];
    if (orgId) {
      const orgRef = db.collection("organizations").doc(orgId);
      const orgDoc = await orgRef.get();
      if (!orgDoc.exists) return res.status(404).json({error: `org ${orgId} not found`});
      orgs = [{id: orgId}];
    } else {
      const orgSnap = await db.collection("organizations").limit(limit).get();
      orgs = orgSnap.docs.map((d) => ({id: d.id}));
    }

    let orgsScanned = 0;
    let templatesScanned = 0;
    let templatesNeedingRepair = 0;
    let tasksWithDefaultTitles = 0;
    let tasksPatched = 0;
    let batchesCommitted = 0;
    let indexNeeded = false;
    const examples = [];

    for (const org of orgs) {
      orgsScanned++;
      let templatesRef = db.collection(`organizations/${org.id}/checklist_templates`).limit(limit);
      if (templateIdQuery) templatesRef = templatesRef.where("__name__", "==", templateIdQuery);
      const templSnap = await templatesRef.get();
      const templDocs = templSnap.docs;

      // process templates with concurrency
      const results = await mapWithConcurrency(templDocs, CONCURRENCY, async (templDoc) => {
        templatesScanned++;
        const templData = templDoc.data();
        if (!templData || !templData.migratedTasks) return null;

        const tasksSnap = await templDoc.ref.collection("tasks").orderBy("order").get();
        const templateTasks = tasksSnap.docs.map((d) => ({id: d.id, ref: d.ref, data: d.data()}));
        const defaultTitled = templateTasks.filter((t) => isDefaultTitle(t.data.title));
        if (defaultTitled.length === 0) return null;
        tasksWithDefaultTitles += defaultTitled.length;

        let candidate = null;
        let candidateSource = null;
        // Strategy A1
        const a1 = await tryA1(templDoc.id, org.id);
        if (a1 && a1.indexLink) {
          indexNeeded = true;
        }
        if (a1 && a1.doc && !a1.error) {
          candidate = a1.doc;
          candidateSource = a1.source;
        }

        // Strategy A2
        if (!candidate) {
          const a2 = await tryA2(templDoc.id, org.id, days);
          if (a2 && a2.doc) {
            candidate = a2.doc;
            candidateSource = a2.source;
          }
        }

        // Strategy A3
        if (!candidate) {
          const a3 = await tryA3(templDoc.id, org.id, days);
          if (a3 && a3.doc) {
            candidate = a3.doc;
            candidateSource = a3.source;
          }
        }

        const candidateTitlesByOrder = {};
        let foundChecklistPath = null;
        const traceSamples = [];
        if (candidate) {
          foundChecklistPath = candidate.ref.path;
          const checklistTasksSnap = await candidate.ref.collection("tasks").orderBy("order").limit(50).get();
          for (const t of checklistTasksSnap.docs) {
            const d = t.data();
            const docId = t.id || (t.ref && t.ref.id) || null;
            const candidateTitle = firstNonEmptyTitle(d);
            const candidateOrder = determineOrder(d, docId);
            if (candidateTitle) candidateTitlesByOrder[String(candidateOrder || (d && d.order) || "")] = candidateTitle;
            // collect trace sample
            if (trace && traceSamples.length < 10) {
              traceSamples.push({order: candidateOrder, candidateTitle: candidateTitle, taskDocId: docId});
            }
          }
        }

        const updates = [];
        for (const t of templateTasks) {
          const curTitle = t.data.title;
          if (!isDefaultTitle(curTitle)) continue;
          const candidateTitle = candidateTitlesByOrder[String(t.data.order)];
          if (candidateTitle && candidateTitle !== curTitle) {
            updates.push({order: t.data.order, id: t.id, from: curTitle, to: candidateTitle, ref: t.ref});
          }
        }

        if (updates.length === 0) return {templPath: templDoc.ref.path, updates: [], candidateSource, foundChecklistPath, traceSamples};

        templatesNeedingRepair++;
        if (diag && examples.length < 10) {
          examples.push({templatePath: templDoc.ref.path, foundChecklistPath, candidateSource, updates: updates.slice(0, 5).map((u) => ({order: u.order, from: u.from, to: u.to}))});
        }

        if (!dryRun) {
          const batch = db.batch();
          for (const u of updates) {
            batch.update(u.ref, {title: u.to, updatedAt: FieldValue.serverTimestamp()});
          }
          await batch.commit();
          batchesCommitted++;
          tasksPatched += updates.length;
        }

        return {templPath: templDoc.ref.path, updates, candidateSource, foundChecklistPath, traceSamples};
      });

      // results processed
    }

    const resp = {
      dryRun,
      databaseId: DB_ID,
      orgsScanned,
      templatesScanned,
      templatesNeedingRepair,
      tasksWithDefaultTitles,
      tasksPatched,
      batchesCommitted,
      indexNeeded,
      examples,
      trace: trace ? [] : undefined,
    };

    // If tracing requested, build a small trace output from the concurrent results
    if (trace) {
      for (const r of results) {
        if (!r) continue;
        const templId = r.templPath ? r.templPath.split("/").pop() : null;
        const recent = [];
        if (r.foundChecklistPath) {
          recent.push({checklistId: r.foundChecklistPath.split("/").pop(), createdAt: null, tasks: (r.traceSamples || []).slice(0, 10)});
        }
        resp.trace.push({templateId: templId, recent});
      }
    }

    res.json(resp);
  } catch (err) {
    console.error(err);
    res.status(500).json({error: String(err)});
  }
});
