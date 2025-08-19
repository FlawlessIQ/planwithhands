#!/usr/bin/env node
// Restore original task names from legacy docs / historical daily_checklists
// Usage: GOOGLE_APPLICATION_CREDENTIALS=/path/key.json node scripts/restore_task_names_from_backups.js --dryRun --orgId=FErQ4pkcrCovJ7T6L13M

const admin = require('firebase-admin');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');

// Simple inline arg parser to avoid external deps
function parseArgs(argvArr) {
  const out = {};
  for (let i = 0; i < argvArr.length; i++) {
    const a = argvArr[i];
    if (!a.startsWith('--')) continue;
    let [k, v] = a.slice(2).split('=');
    if (v === undefined && i + 1 < argvArr.length && !argvArr[i + 1].startsWith('--')) {
      v = argvArr[++i];
    }
    if (v === undefined) v = 'true'; // flag-only
    out[k] = v;
  }
  return out;
}
const argv = parseArgs(process.argv.slice(2));
const asBool = v => /^(1|true|yes)$/i.test(String(v ?? 'false'));
const dryRun = !/^(false|0|no)$/i.test(String(argv.dryRun ?? 'true'));
const trace = asBool(argv.trace);

if (argv.help) {
  console.log(`Usage: GOOGLE_APPLICATION_CREDENTIALS=/path/key.json node scripts/restore_task_names_from_backups.js [--dryRun] [--orgId=<orgId>] [--limit=N]

Options:
  --dryRun (default true)  Do not commit changes, only log
  --orgId                  Limit to a single organization
  --limit                  Limit templates per org or search size
  --backupPrefix           Prefix for backup collection (default checklists_backup_)
  --days                  Lookback for daily_checklists (default 3650)
  --before                ISO timestamp to limit historical search
  --trace                 Include trace logs for each template
`);
  process.exit(0);
}

// Initialize admin
if (!admin.apps.length) {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath && fs.existsSync(credPath)) {
    admin.initializeApp({ credential: admin.credential.cert(require(credPath)) });
  } else {
    admin.initializeApp();
  }
}

const DB_ID = process.env.FIRESTORE_DB_ID || '(default)';
const db = getFirestore(admin.app(), DB_ID);

const DRY_RUN = dryRun;
const ORG_ID = argv.orgId;
const LIMIT = Number(argv.limit || 200);
const DAYS = Number(argv.days || 365);
const BEFORE = argv.before ? new Date(argv.before) : null;
const BACKUP_PREFIX = argv.backupPrefix || 'checklists_backup_';
const TRACE = trace;

const DEFAULT_ORDER_PARSE = /(?:task[_-]?)?(\d+)$/i;

function isDefaultTitle(title) {
  return /^Task\s+\d+$/i.test(String(title || ''));
}

function firstNonEmptyTitle(d) {
  if (!d) return null;
  return (d.title && String(d.title).trim()) || (d.name && String(d.name).trim()) || (d.task && String(d.task).trim()) || (d.label && String(d.label).trim()) || null;
}

function determineOrder(d, docId) {
  if (!d && !docId) return null;
  const candidates = [d && d.order, d && d.index, d && d.position, d && d.sort];
  for (const c of candidates) {
    if (c !== undefined && c !== null && c !== '') {
      const n = parseInt(c, 10);
      if (!Number.isNaN(n)) return n;
    }
  }
  if (docId) {
    const m = docId.match(DEFAULT_ORDER_PARSE);
    if (m) return parseInt(m[1], 10);
  }
  return null;
}

async function listOrgs(limit = LIMIT) {
  if (ORG_ID) return [ORG_ID];
  const snap = await db.collection('organizations').limit(limit).get();
  return snap.docs.map(d => d.id);
}

async function findLegacyTemplateDoc(orgId, templateId) {
  // try a few plausible legacy collection names
  const names = ['checklist_templates_old', 'checklist_templates_backup', 'checklist_templates_archive', 'checklist_templates_history'];
  for (const n of names) {
    try {
      const ref = db.collection(`organizations/${orgId}/${n}`).doc(templateId);
      const doc = await ref.get();
      if (doc.exists) return { source: `org/${n}`, doc: doc.data() };
    } catch (e) {
      // ignore
    }
  }
  // also try top-level collectionGroup search (rare)
  return null;
}

async function gatherTitlesFromDailyChecklists(templateId, orgId, limit = 200, beforeDate = BEFORE) {
  // returns map order -> most common candidate title (string) and trace samples
  const mapCounts = {}; // {order: {title: count}}
  const traceLists = [];
  try {
    let q = db.collectionGroup('daily_checklists').where('templateId', '==', templateId).orderBy('createdAt', 'desc').limit(limit);
    if (orgId) q = q.where('orgId', '==', orgId);
    if (beforeDate) q = q.where('createdAt', '<=', beforeDate);
    const snap = await q.get();
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      const createdAt = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate() : (d.createdAt instanceof Date ? d.createdAt : null);
      const tasks = d.tasks || [];
      const sample = [];
      for (let i = 0; i < tasks.length && i < 50; i++) {
        const t = tasks[i];
        const candidateTitle = (t && (t.title || t.name || t.task || t.label)) || null;
        const order = (t && (t.order !== undefined ? t.order : (t.index !== undefined ? t.index : (t.position !== undefined ? t.position : null)))) || null;
        const docId = t && t.id ? String(t.id) : null;
        const ordKey = order !== null && order !== undefined ? String(order) : (docId ? docId : `idx_${i}`);
        if (candidateTitle && String(candidateTitle).trim()) {
          mapCounts[ordKey] = mapCounts[ordKey] || {};
          mapCounts[ordKey][String(candidateTitle).trim()] = (mapCounts[ordKey][String(candidateTitle).trim()] || 0) + 1;
        }
        if (TRACE && sample.length < 10) sample.push({ order, candidateTitle: candidateTitle || null, taskDocId: docId });
      }
      if (TRACE && sample.length) {
        traceLists.push({ checklistId: doc.id, createdAt: createdAt ? createdAt.toISOString() : null, tasks: sample });
      }
    }
  } catch (e) {
    console.error('daily_checklists collectionGroup scan failed:', e.message || e);
  }
  // reduce to chosenTitle per order: pick most frequent
  const chosen = {};
  for (const ordKey of Object.keys(mapCounts)) {
    const titles = mapCounts[ordKey];
    let best = null, bestCount = 0;
    for (const t of Object.keys(titles)) {
      if (titles[t] > bestCount) { best = t; bestCount = titles[t]; }
    }
    if (best) chosen[ordKey] = best;
  }
  return { chosen, traceLists };
}

async function findOriginalTitles(templateId, orgId) {
  // Try legacy template doc first
  const res = {};
  const legacy = await findLegacyTemplateDoc(orgId, templateId);
  if (legacy && legacy.doc && Array.isArray(legacy.doc.tasks)) {
    for (const t of legacy.doc.tasks) {
      const order = t.order !== undefined ? t.order : (t.index !== undefined ? t.index : null);
      if (order !== null && order !== undefined && t.name) res[String(order)] = String(t.name);
    }
    if (Object.keys(res).length) return { map: res, source: legacy.source };
  }

  // fallback: scan daily_checklists and aggregate
  const { chosen, traceLists } = await gatherTitlesFromDailyChecklists(templateId, orgId, LIMIT, BEFORE);
  if (Object.keys(chosen).length) return { map: chosen, source: 'daily_checklists', traceLists };

  // fallback: search organizations/{orgId}/checklists and locations/*/checklists
  try {
    const templCollections = [`organizations/${orgId}/checklists`, `organizations/${orgId}/checklist_templates`];
    for (const coll of templCollections) {
      const snap = await db.collection(coll).where('templateId', '==', templateId).limit(LIMIT).get();
      for (const doc of snap.docs) {
        const d = doc.data() || {};
        const tasks = d.tasks || [];
        for (const t of tasks) {
          const order = t.order !== undefined ? t.order : (t.index !== undefined ? t.index : null);
          if (order !== null && order !== undefined && t.name) res[String(order)] = String(t.name);
        }
      }
      if (Object.keys(res).length) return { map: res, source: coll };
    }
  } catch (e) {
    // ignore
  }

  return { map: res, source: null };
}

async function backupDoc(path, docData) {
  const ts = new Date().toISOString().replace(/[:.]/g,'-');
  const backupPath = `backups/${BACKUP_PREFIX}${ts}/${path}`;
  // write a document with original data
  try {
    await db.collection(backupPath).doc('_meta').set({ restoredAt: FieldValue.serverTimestamp(), originalPath: path, snapshot: docData });
    return true;
  } catch (e) {
    console.error('backup failed for', path, e.message || e);
    return false;
  }
}

async function updateTemplateTasks(orgId, templateId, mapping, dryRun = DRY_RUN) {
  const templRef = db.doc(`organizations/${orgId}/checklist_templates/${templateId}`);
  const templSnap = await templRef.get();
  if (!templSnap.exists) return { skipped: 0, restored: 0, failed: 0, reason: 'template-not-found' };
  const data = templSnap.data() || {};
  const tasks = data.tasks || [];
  const updates = [];
  for (let i = 0; i < tasks.length; i++) {
    const t = tasks[i];
    const curTitle = t.title || t.name || '';
    if (!isDefaultTitle(curTitle)) continue; // only repair default titles
    // try to identify stable order key
    const order = t.order !== undefined ? t.order : (t.index !== undefined ? t.index : null);
    const key = order !== null && order !== undefined ? String(order) : (t.id ? t.id : String(i));
    const candidate = mapping[key] || mapping[String(order)] || mapping[String(t.id)] || mapping[key];
    if (candidate && candidate !== curTitle) {
      updates.push({ index: i, from: curTitle, to: candidate });
    }
  }

  if (updates.length === 0) return { skipped: tasks.length, restored: 0, failed: 0 };

  if (dryRun) {
    return { skipped: tasks.length - updates.length, restored: updates.length, updates };
  }

  // backup
  await backupDoc(`organizations/${orgId}/checklist_templates/${templateId}`, data);

  // apply updates in-place
  const newTasks = tasks.map((t, idx) => {
    const u = updates.find(x => x.index === idx);
    if (!u) return t;
    const nt = Object.assign({}, t);
    if (nt.title !== undefined) nt.title = u.to; else nt.name = u.to;
    nt.updatedAt = FieldValue.serverTimestamp();
    return nt;
  });

  // write with retry
  const maxAttempts = 3;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await templRef.update({ tasks: newTasks, updatedAt: FieldValue.serverTimestamp() });
      return { skipped: tasks.length - updates.length, restored: updates.length, failed: 0 };
    } catch (e) {
      console.error(`update attempt ${attempt} failed for ${templateId}:`, e.message || e);
      if (attempt === maxAttempts) return { skipped: 0, restored: 0, failed: updates.length, error: String(e) };
      await new Promise(r => setTimeout(r, attempt * 1000));
    }
  }
}

(async function main() {
  console.log('restore_task_names_from_backups starting', { DRY_RUN, ORG_ID, LIMIT, DAYS, BEFORE: BEFORE ? BEFORE.toISOString() : null });

  // New flags: listTemplates, traceTemplate, onlyTemplate
  const LIST_TEMPLATES = !!argv.listTemplates;
  const TRACE_TEMPLATE = argv.traceTemplate || null;
  const ONLY_TEMPLATE = argv.onlyTemplate || null;
  const FIND_DAILY = argv.findDailyChecklistsByTemplate || null;
  const PRINT_TEMPLATE_TASKS = !!argv.printTemplateTasks;
  const PRINT_TEMPLATE_ID = argv.templateId || null;
  const EXPORT_TEMPLATE_CSV = !!argv.exportTemplateTasksCsv;
  const EXPORT_OUT = argv.out || null;
  const EXPORT_LIMIT = Number(argv.limit || 500);

  if (LIST_TEMPLATES) {
    // Scan checklist_templates and count default-titled tasks in subcollection /tasks
    const out = [];
    const templSnap = await db.collection(`organizations/${ORG_ID}/checklist_templates`).limit(LIMIT).get();
    for (const templDoc of templSnap.docs) {
      const templId = templDoc.id;
      const templData = templDoc.data() || {};
      const name = templData.name || templData.title || templId;
      // count tasks in subcollection
      let defaultCount = 0;
      try {
        const tasksSnap = await templDoc.ref.collection('tasks').get();
        for (const tdoc of tasksSnap.docs) {
          const td = tdoc.data() || {};
          const curTitle = td.title || td.name || '';
          if (isDefaultTitle(curTitle)) defaultCount++;
        }
      } catch (e) {
        // ignore
      }
      if (defaultCount > 0) out.push({ templateId: templId, templatePath: templDoc.ref.path, templateName: name, defaultCount });
    }
    out.sort((a,b) => b.defaultCount - a.defaultCount);
    console.log(JSON.stringify(out, null, 2));
    process.exit(0);
  }

  if (TRACE_TEMPLATE) {
    const templateId = TRACE_TEMPLATE;
    // collect up to 3 recent daily_checklists for this template
    const samples = [];
    try {
      // helper to coalesce numeric order
      const coalesceNumber = (...vals) => {
        for (const v of vals) {
          if (v === undefined || v === null || v === '') continue;
          const n = parseInt(String(v), 10);
          if (!Number.isNaN(n)) return n;
        }
        return null;
      };
      const parseIntFromDocId = (docId) => {
        if (!docId) return null;
        const m = String(docId).match(/(\d+)$/);
        return m ? parseInt(m[1], 10) : null;
      };

      // build query: always filter by templateId; add orgId filter only if provided
      let q = db.collectionGroup('daily_checklists').where('templateId', '==', templateId);
      if (ORG_ID) q = q.where('orgId', '==', ORG_ID);

      // apply createdAt window: if user provided days or before, use them; otherwise default to 10 years back
      const tenYearsMs = 10 * 365 * 24 * 60 * 60 * 1000;
      const startDate = argv.days ? new Date(Date.now() - (Number(argv.days) * 24 * 60 * 60 * 1000)) : new Date(Date.now() - tenYearsMs);
      if (startDate) q = q.where('createdAt', '>=', startDate);
      if (BEFORE) q = q.where('createdAt', '<=', BEFORE);

      q = q.orderBy('createdAt', 'desc').limit(3);

      const snap = await q.get();
      for (const doc of snap.docs) {
        const d = doc.data() || {};
        const createdAt = d.createdAt && d.createdAt.toDate ? d.createdAt.toDate().toISOString() : (d.createdAt instanceof Date ? d.createdAt.toISOString() : null);
        const tasks = d.tasks || [];
        const taskSamples = [];
        for (let i = 0; i < tasks.length && taskSamples.length < 10; i++) {
          const tt = tasks[i] || {};
          // title fallback order: title, name, label, task, description
          const tstr = (tt.title || tt.name || tt.label || tt.task || tt.description || '').toString().trim();
          const o = coalesceNumber(tt.order, tt.index, tt.position, tt.sort, tt.seq) ?? parseIntFromDocId(tt.id);
          if (!tstr) continue; // skip empty
          taskSamples.push({ order: o, id: tt.id || null, title: tstr, raw: { title: tt.title, name: tt.name, label: tt.label, task: tt.task, description: tt.description }, docId: tt.id || null });
        }
        samples.push({ checklistId: doc.id, createdAt, tasks: taskSamples });
      }
    } catch (e) {
      console.error('traceTemplate failed:', String(e));
    }

    if (!samples.length) {
      const hint = { noOrgIdFilter: !argv.orgId, days: argv.days ? Number(argv.days) : undefined, before: BEFORE ? BEFORE.toISOString() : undefined, reason: 'no matching daily_checklists found' };
      console.log(JSON.stringify({ templateId: TRACE_TEMPLATE, samples: [], hint }, null, 2));
      process.exit(0);
    }

    console.log(JSON.stringify({ templateId: TRACE_TEMPLATE, samples }, null, 2));
    process.exit(0);
  }

  if (FIND_DAILY) {
    const templateId = FIND_DAILY;
    const fields = ['templateId','template_id','templateID','template'];
    const matches = [];
    let totalHits = 0;
    let sampleDoc = null;
    for (const f of fields) {
      try {
        // try with orderBy createdAt desc first
        let q = db.collectionGroup('daily_checklists').where(f, '==', templateId).orderBy('createdAt', 'desc').limit(LIMIT);
        let snap;
        try {
          snap = await q.get();
        } catch (e) {
          // fallback to query without orderBy (or if createdAt missing/index issue)
          q = db.collectionGroup('daily_checklists').where(f, '==', templateId).limit(LIMIT);
          snap = await q.get();
        }
        if (snap && !snap.empty) {
          const paths = snap.docs.slice(0, 10).map(d => d.ref.path);
          matches.push({ field: f, hits: snap.size, paths });
          totalHits += snap.size;
          if (!sampleDoc) {
            const d0 = snap.docs[0];
            sampleDoc = { path: d0.ref.path, keys: Object.keys(d0.data() || {}) };
          }
        } else {
          matches.push({ field: f, hits: 0, paths: [] });
        }
      } catch (err) {
        // record as zero hits but keep going
        matches.push({ field: f, hits: 0, paths: [], error: String(err) });
      }
    }
    console.log(JSON.stringify({ templateId, matches, totalHits, sampleDoc }, null, 2));
    process.exit(0);
  }

  if (PRINT_TEMPLATE_TASKS) {
    // require orgId and templateId
    if (!ORG_ID || !PRINT_TEMPLATE_ID) {
      console.error('Error: --printTemplateTasks requires --orgId and --templateId');
      process.exit(1);
    }
    const limitTasks = Number(argv.limit || 20);
    const collRef = db.collection(`organizations/${ORG_ID}/checklist_templates/${PRINT_TEMPLATE_ID}/tasks`);
    let q = collRef.limit(limitTasks);
    try {
      q = collRef.orderBy('order').limit(limitTasks);
    } catch (e) {
      q = collRef.orderBy('__name__').limit(limitTasks);
    }
    try {
      const snap = await q.get();
      const tasks = snap.docs.map(d => {
        const dt = d.data() || {};
        const coerceTs = v => {
          if (!v) return null;
          if (v.toDate) return v.toDate().toISOString();
          if (v instanceof Date) return v.toISOString();
          return String(v);
        };
        return {
          id: d.id,
          title: (dt.title || dt.name || '').toString(),
          order: dt.order !== undefined ? dt.order : null,
          index: dt.index !== undefined ? dt.index : null,
          position: dt.position !== undefined ? dt.position : null,
          sort: dt.sort !== undefined ? dt.sort : null,
          createdAt: coerceTs(dt.createdAt),
          updatedAt: coerceTs(dt.updatedAt)
        };
      });
      console.log(JSON.stringify({ orgId: ORG_ID, templateId: PRINT_TEMPLATE_ID, count: tasks.length, tasks }, null, 2));
      process.exit(0);
    } catch (e) {
      console.error('Failed to read tasks:', String(e));
      process.exit(1);
    }
  }

  if (EXPORT_TEMPLATE_CSV) {
    // require orgId and templateId
    if (!ORG_ID || !PRINT_TEMPLATE_ID) {
      console.error('Error: --exportTemplateTasksCsv requires --orgId and --templateId');
      process.exit(1);
    }
    const limitTasks = Number(argv.limit || EXPORT_LIMIT || 500);
    const collRef = db.collection(`organizations/${ORG_ID}/checklist_templates/${PRINT_TEMPLATE_ID}/tasks`);
    let q = collRef.limit(limitTasks);
    try {
      q = collRef.orderBy('order', 'asc').limit(limitTasks);
    } catch (e) {
      q = collRef.orderBy('__name__').limit(limitTasks);
    }
    try {
      const snap = await q.get();
      // CSV header exact: orgId,templateId,taskId,order,currentTitle,newTitle
      const rows = [];
      const esc = v => '"' + String(v === undefined || v === null ? '' : String(v)).replace(/"/g, '""') + '"';
      rows.push('orgId,templateId,taskId,order,currentTitle,newTitle');
      for (const d of snap.docs) {
        const dt = d.data() || {};
        const orderVal = dt.order !== undefined && dt.order !== null ? dt.order : '';
        const curTitle = (dt.title || dt.name || '') || '';
        const line = [esc(ORG_ID), esc(PRINT_TEMPLATE_ID), esc(d.id), esc(orderVal), esc(curTitle), esc('')].join(',');
        rows.push(line);
      }
      const csv = rows.join('\n') + '\n';
      if (EXPORT_OUT) {
        const outPath = path.resolve(String(EXPORT_OUT));
        const dir = path.dirname(outPath);
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(outPath, csv, 'utf8');
        console.log('Wrote CSV to', outPath);
      } else {
        // print to stdout
        process.stdout.write(csv);
      }
      process.exit(0);
    } catch (e) {
      console.error('Failed to export CSV:', String(e));
      process.exit(1);
    }
  }
  const orgs = await listOrgs(LIMIT);
  let totalRestored = 0, totalSkipped = 0, totalFailed = 0, totalTemplates = 0;
  const traces = [];

  for (const orgId of orgs) {
    console.log('processing org', orgId);
    // list templates
    const templSnap = await db.collection(`organizations/${orgId}/checklist_templates`).limit(LIMIT).get();
    for (const templDoc of templSnap.docs) {
      totalTemplates++;
      const tid = templDoc.id;
  if (ONLY_TEMPLATE && tid !== ONLY_TEMPLATE) continue;
      const templData = templDoc.data() || {};
      // only operate on templates whose tasks array exists and contains default titles
      const tasks = templData.tasks || [];
      const defaultCount = tasks.filter(t => isDefaultTitle(t && (t.title || t.name))).length;
      if (defaultCount === 0) continue;

      console.log(`template ${tid} has ${defaultCount} default-titled tasks`);

      // find original titles
      const found = await findOriginalTitles(tid, orgId);
      if (TRACE && found.traceLists) {
        traces.push({ templateId: tid, source: found.source, traceLists: found.traceLists.slice(0,3) });
      }

      // mapping keys guessed may be numeric strings or docId
      const mapping = found.map || {};
      const result = await updateTemplateTasks(orgId, tid, mapping, DRY_RUN);
      if (result.restored) totalRestored += result.restored;
      if (result.skipped) totalSkipped += result.skipped;
      if (result.failed) totalFailed += result.failed;
      console.log('result for', tid, result);
    }
  }

  console.log({ totalTemplates, totalRestored, totalSkipped, totalFailed });
  if (TRACE && traces.length) {
    console.log('traces:');
    console.log(JSON.stringify(traces, null, 2));
  }
  console.log('done.');
  process.exit(0);
})();
