#!/usr/bin/env node
// Check which collections have expiresAt present on sample documents
// Usage: node functions/scripts/checkExpiresAtStatus.js

const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const argv = process.argv.slice(2);
const SAMPLE_LIMIT = 5; // per requirement

function parseListArg(name) {
  const arg = argv.find(a => a.startsWith(`${name}=`));
  if (!arg) return null;
  return arg.split('=')[1].split(',').map(s => s.trim()).filter(Boolean);
}

async function discoverWildcardCollections(pattern) {
  // Find root collection names and subcollection names matching pattern (supports '*' wildcard)
  const regex = new RegExp('^' + pattern.replace(/[-/\\^$+?.()|[\]{}]/g, '\\$&').replace(/\\\*/g, '.*') + '$');
  const names = new Set();
  try {
    const roots = await db.listCollections();
    for (const c of roots) {
      if (regex.test(c.id)) names.add(c.id);
    }
    // For each root, sample some docs to find subcollection ids
    for (const c of roots) {
      try {
        const snap = await db.collection(c.id).limit(50).get();
        for (const doc of snap.docs) {
          try {
            const subs = await doc.ref.listCollections();
            for (const sc of subs) {
              if (regex.test(sc.id)) names.add(sc.id);
            }
          } catch (e) {
            // ignore
          }
        }
      } catch (e) {
        // ignore per-collection errors
      }
    }
  } catch (e) {
    console.warn('Could not run wildcard discovery:', e.message || e);
  }
  return Array.from(names);
}

async function sampleCollectionGroup(id) {
  const snap = await db.collectionGroup(id).limit(SAMPLE_LIMIT).get();
  const sampleDocPaths = [];
  const sampleExpiresAt = [];
  let hasExpiresAt = false;
  for (const doc of snap.docs) {
    sampleDocPaths.push(doc.ref.path);
    const data = doc.data() || {};
    sampleExpiresAt.push(data.expiresAt ? (data.expiresAt.toDate ? data.expiresAt.toDate().toISOString() : data.expiresAt) : null);
    if (data.expiresAt) hasExpiresAt = true;
  }
  return { collection: id, type: 'collectionGroup', hasExpiresAt, sampleDocPaths, sampleExpiresAt };
}

async function sampleTopLevelCollection(id) {
  const snap = await db.collection(id).limit(SAMPLE_LIMIT).get();
  const sampleDocPaths = [];
  const sampleExpiresAt = [];
  let hasExpiresAt = false;
  for (const doc of snap.docs) {
    sampleDocPaths.push(doc.ref.path);
    const data = doc.data() || {};
    sampleExpiresAt.push(data.expiresAt ? (data.expiresAt.toDate ? data.expiresAt.toDate().toISOString() : data.expiresAt) : null);
    if (data.expiresAt) hasExpiresAt = true;
  }
  return { collection: id, type: 'top-level', hasExpiresAt, sampleDocPaths, sampleExpiresAt };
}

async function main() {
  const results = [];

  // Candidate collections
  const jobs = [
    { id: 'daily_checklists', type: 'collectionGroup' },
    { id: 'tasks', type: 'collectionGroup' },
    { id: 'invites', type: 'collectionGroup' },
    { id: 'invites', type: 'top-level' },
    { id: 'notifications', type: 'collectionGroup' },
    { id: 'notifications', type: 'top-level' },
    { id: 'messages', type: 'collectionGroup' },
    // daily_summary* will be expanded
    { id: 'daily_summary', type: 'collectionGroup' },
    { id: 'daily_summary', type: 'top-level' },
    { id: 'temp', type: 'top-level' },
    { id: '_test', type: 'top-level' },
    { id: 'debug', type: 'top-level' },
  ];

  // Expand daily_summary_* wildcard
  const wildcardMatches = await discoverWildcardCollections('daily_summary_*');
  for (const name of wildcardMatches) {
    // add both group and root variants so we check both
    jobs.push({ id: name, type: 'collectionGroup' });
    jobs.push({ id: name, type: 'top-level' });
  }

  // De-duplicate jobs by id+type
  const unique = [];
  const seen = new Set();
  for (const j of jobs) {
    const k = `${j.type}::${j.id}`;
    if (!seen.has(k)) { seen.add(k); unique.push(j); }
  }

  for (const job of unique) {
    try {
      if (job.type === 'collectionGroup') {
        const res = await sampleCollectionGroup(job.id);
        results.push(res);
      } else {
        // check existence quickly
        const exists = await db.collection(job.id).limit(1).get();
        if (exists.empty) {
          results.push({ collection: job.id, type: job.type, hasExpiresAt: false, sampleDocPaths: [], sampleExpiresAt: [] });
        } else {
          const res = await sampleTopLevelCollection(job.id);
          results.push(res);
        }
      }
    } catch (e) {
      results.push({ collection: job.id, type: job.type, error: e.message || String(e) });
    }
  }

  console.log(JSON.stringify({ sampleLimit: SAMPLE_LIMIT, results }, null, 2));
}

if (require.main === module) {
  main().catch(err => { console.error(err); process.exit(2); });
}

module.exports = { main };
