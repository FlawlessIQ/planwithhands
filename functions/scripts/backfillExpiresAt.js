#!/usr/bin/env node
// Backfill missing expiresAt fields for ephemeral collections
// Usage: node functions/scripts/backfillExpiresAt.js

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const BATCH_SIZE = 500;
const PAGE_SIZE = 1000;
const DEFAULT_TTL_DAYS = 30;
const INVITE_TTL_DAYS = 7;

const argv = process.argv.slice(2);
const DRY_RUN = argv.includes('--dry-run');

// Parse --include and --exclude CLI flags. Comma-separated list of job keys.
function parseListArg(name) {
  const arg = argv.find(a => a.startsWith(`${name}=`));
  if (!arg) return null;
  return arg.split('=')[1].split(',').map(s => s.trim()).filter(Boolean);
}

const INCLUDE = parseListArg('--include');
const EXCLUDE = parseListArg('--exclude');

// Parse --sample-size=N (default 500)
function parseNumberArg(name, defaultValue) {
  const arg = argv.find(a => a.startsWith(`${name}=`));
  if (!arg) return defaultValue;
  const v = Number(arg.split('=')[1]);
  return Number.isFinite(v) && v > 0 ? Math.floor(v) : defaultValue;
}

const SAMPLE_SIZE = parseNumberArg('--sample-size', 500);
const REQUIRE_CONFIRM = argv.includes('--require-confirm');
const readline = require('readline');

function shouldRunJob(key) {
  // Support wildcard patterns in INCLUDE/EXCLUDE (e.g. daily_summary_*)
  const matchesAny = (value, patterns) => {
    if (!patterns) return false;
    for (const p of patterns) {
      // Treat plain string as literal, '*' as wildcard
      const regex = new RegExp('^' + p.replace(/[-/\\^$+?.()|[\]{}]/g, '\\$&').replace(/\\\*/g, '.*') + '$');
      if (regex.test(value)) return true;
    }
    return false;
  };

  if (INCLUDE && !matchesAny(key, INCLUDE)) return false;
  if (EXCLUDE && matchesAny(key, EXCLUDE)) return false;
  return true;
}

// Expand wildcard pattern by listing root collections and scanning sample documents for subcollection names
async function expandWildcardCollections(pattern, ttlDays) {
  const results = [];
  // Build regex from pattern (support '*' wildcard)
  const regex = new RegExp('^' + pattern.replace(/[-/\\^$+?.()|[\]{}]/g, '\\$&').replace(/\\\*/g, '.*') + '$');

  // 1) Check root collections
  try {
    const rootCols = await db.listCollections();
    for (const c of rootCols) {
      const name = c.id;
      if (regex.test(name)) {
        const key = `${name}_root`;
        results.push({ key, type: 'topLevel', id: name, ttl: ttlDays });
      }
    }
  } catch (e) {
    console.warn('Could not list root collections:', e.message || e);
  }

  // 2) Scan a sample of documents from each root collection to find subcollection names that match
  try {
    const rootCols = await db.listCollections();
    const discovered = new Set();
    for (const c of rootCols) {
      const col = db.collection(c.id);
      const snap = await col.limit(SAMPLE_SIZE).get(); // sample up to SAMPLE_SIZE docs per collection
      for (const doc of snap.docs) {
        try {
          const subs = await doc.ref.listCollections();
          for (const sc of subs) {
            if (regex.test(sc.id) && !discovered.has(sc.id)) {
              discovered.add(sc.id);
              const key = `${sc.id}_group`;
              results.push({ key, type: 'collectionGroup', id: sc.id, ttl: ttlDays });
            }
          }
        } catch (e) {
          // ignore per-doc list failures
        }
      }
    }
  } catch (e) {
    console.warn('Could not scan subcollections for wildcard expansion:', e.message || e);
  }

  return results;
}

function ttlTimestampFromDays(days) {
  return admin.firestore.Timestamp.fromDate(new Date(Date.now() + days * 24 * 60 * 60 * 1000));
}

async function processCollectionGroup(collectionId, ttlDays = DEFAULT_TTL_DAYS, filterFn = null) {
  console.log(`Scanning collectionGroup ${collectionId} (ttlDays=${ttlDays})`);
  const pageSize = PAGE_SIZE;
  let last = null;
  let processed = 0;
  let updated = 0;
  const planned = [];

  while (true) {
    let q = db.collectionGroup(collectionId).limit(pageSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    let batch = db.batch();
    let batchOps = 0;

    for (const doc of snap.docs) {
      processed++;
      const data = doc.data() || {};
      // Skip if already has expiresAt
      if (data.expiresAt) continue;
      // If a filter function was provided, use it to decide whether to update
      // Pass the full doc so callers can inspect path and data
      if (filterFn && !filterFn(doc)) continue;

      // Record plan or apply update
      if (DRY_RUN) {
        planned.push(doc.ref.path);
        updated++;
        batchOps++; // keep counting so behavior is similar
      } else {
        batch.update(doc.ref, { expiresAt: ttlTimestampFromDays(ttlDays) });
        batchOps++;
        updated++;
      }

      if (batchOps >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      }
    }

      if (!DRY_RUN && batchOps > 0) await batch.commit();

      // If dry-run, periodically log a progress sample to avoid growing memory
      if (DRY_RUN && planned.length > 10000) {
        console.log(`DRY RUN: planned updates for ${collectionId} so far: ${planned.length} (trimming stored paths)`);
        planned.splice(0, planned.length - 1000);
      }

    last = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }

  if (DRY_RUN) {
    console.log(`collectionGroup ${collectionId}: processed=${processed}, would_update=${updated}`);
    console.log(`DRY RUN sample paths (up to 100):`, planned.slice(0, 100));
  } else {
    console.log(`collectionGroup ${collectionId}: processed=${processed}, updated=${updated}`);
  }
  return { processed, updated, samplePaths: planned.slice(0, 100) };
}

async function processTopLevelCollection(collectionPath, ttlDays = DEFAULT_TTL_DAYS, filterFn = null) {
  console.log(`Scanning collection ${collectionPath} (ttlDays=${ttlDays})`);
  const pageSize = PAGE_SIZE;
  let last = null;
  let processed = 0;
  let updated = 0;
  const planned = [];

  while (true) {
    let q = db.collection(collectionPath).limit(pageSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    let batch = db.batch();
    let batchOps = 0;

    for (const doc of snap.docs) {
      processed++;
      const data = doc.data() || {};
      if (data.expiresAt) continue;
      // Pass full doc to filter function for consistency with collectionGroup
      if (filterFn && !filterFn(doc)) continue;

      if (DRY_RUN) {
        planned.push(doc.ref.path);
        updated++;
        batchOps++;
      } else {
        batch.update(doc.ref, { expiresAt: ttlTimestampFromDays(ttlDays) });
        batchOps++;
        updated++;
      }

      if (batchOps >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      }
    }

    if (!DRY_RUN && batchOps > 0) await batch.commit();

    if (DRY_RUN && planned.length > 10000) {
      console.log(`DRY RUN: planned updates for ${collectionPath} so far: ${planned.length} (trimming stored paths)`);
      planned.splice(0, planned.length - 1000);
    }

    last = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }

    if (DRY_RUN) {
    console.log(`collection ${collectionPath}: processed=${processed}, would_update=${updated}`);
    console.log(`DRY RUN sample paths (up to 100):`, planned.slice(0, 100));
  } else {
    console.log(`collection ${collectionPath}: processed=${processed}, updated=${updated}`);
  }
  return { processed, updated, samplePaths: planned.slice(0, 100) };
}

async function main() {
  try {
    const results = {};

  // Build job list and run according to include/exclude flags
  let jobs = [
      { key: 'daily_checklists', type: 'collectionGroup', id: 'daily_checklists', ttl: DEFAULT_TTL_DAYS },
      { key: 'tasks', type: 'collectionGroup', id: 'tasks', ttl: DEFAULT_TTL_DAYS, filter: (doc) => {
        const data = doc.data() || {};
        const path = doc.ref.path || '';
        // Only process runtime tasks: either they belong to a daily_checklist path OR have explicit checklist identifiers
        return path.includes('/daily_checklists/') || Boolean(data.dailyChecklistId || data.checklistId);
      } },

      // Invites (both org-scoped and legacy root)
      { key: 'invites_group', type: 'collectionGroup', id: 'invites', ttl: INVITE_TTL_DAYS },
      { key: 'invites_root', type: 'topLevel', id: 'invites', ttl: INVITE_TTL_DAYS },

      // Notifications
      { key: 'notifications_group', type: 'collectionGroup', id: 'notifications', ttl: DEFAULT_TTL_DAYS },
      { key: 'notifications_root', type: 'topLevel', id: 'notifications', ttl: DEFAULT_TTL_DAYS },

      // User messages (ephemeral notices) - users/*/messages
      { key: 'messages_group', type: 'collectionGroup', id: 'messages', ttl: DEFAULT_TTL_DAYS },

      // Daily summary logs (and similar prefixes) - keep a few reasonable candidates
      { key: 'daily_summary_logs_group', type: 'collectionGroup', id: 'daily_summary_logs', ttl: 90 },
      { key: 'daily_summary_group', type: 'collectionGroup', id: 'daily_summary', ttl: 90 },
      { key: 'daily_summary_logs_root', type: 'topLevel', id: 'daily_summary_logs', ttl: 90 },
      { key: 'daily_summary_root', type: 'topLevel', id: 'daily_summary', ttl: 90 },

      // Ephemeral debug/top-level collections
      { key: 'temp_root', type: 'topLevel', id: 'temp', ttl: INVITE_TTL_DAYS },
      { key: '_test_root', type: 'topLevel', id: '_test', ttl: INVITE_TTL_DAYS },
      { key: 'debug_root', type: 'topLevel', id: 'debug', ttl: INVITE_TTL_DAYS },
    ];

    // If INCLUDE contains wildcard patterns, expand them into jobs
    const wildcardIncludes = INCLUDE ? INCLUDE.filter(p => p.includes('*')) : [];
    if (wildcardIncludes.length) {
      // capture initial job keys so we can log only newly discovered jobs
      const initialKeys = new Set(jobs.map(j => j.key));
      for (const pattern of wildcardIncludes) {
        // For now only support daily_summary_* pattern mapping to 90 days; you can expand mapping as needed
        const ttl = pattern.startsWith('daily_summary') ? 90 : DEFAULT_TTL_DAYS;
        const discovered = await expandWildcardCollections(pattern, ttl);
        // Merge discovered jobs, avoiding duplicate keys
        for (const dj of discovered) {
          if (!jobs.some(j => j.key === dj.key)) jobs.push(dj);
        }
      }

      // After expansion, log wildcard-matching jobs (test each pattern against job.id and job.key)
      const patternsRegex = wildcardIncludes.map(p => new RegExp('^' + p.replace(/[-/\\^$+?.()|[\]{}]/g, '\\$&').replace(/\\\*/g, '.*') + '$'));
      const matchedJobs = jobs.filter(j => patternsRegex.some(rx => rx.test(j.id) || rx.test((j.key || '').replace(/_(group|root)$/, ''))));
      if (matchedJobs.length) {
        console.log('Discovered wildcard jobs:');
        for (const j of matchedJobs) {
          const typeLabel = j.type === 'collectionGroup' ? 'collectionGroup' : 'top-level';
          console.log(`  • ${j.key} (${typeLabel}, id=${j.id}, ttl=${j.ttl}d)`);
        }
      }

      // If not a dry-run, enforce require-confirm when wildcards are used
      if (!DRY_RUN) {
        if (!REQUIRE_CONFIRM) {
          console.error('Error: Wildcards require --require-confirm for non-dry-run runs');
          process.exit(2);
        }

        // Prompt for explicit confirmation
        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
        const answer = await new Promise(resolve => rl.question(`Proceed with ${matchedJobs.length} discovered jobs? (yes/no) `, ans => { rl.close(); resolve(ans && ans.trim()); }));
        if (String(answer).toLowerCase() !== 'yes') {
          console.log('Aborted by operator');
          process.exit(0);
        }
      }
    }

    for (const job of jobs) {
      // Match include/exclude against both job.key and job.id (collection name)
      const runForKey = shouldRunJob(job.key) || shouldRunJob(job.id);
      if (!runForKey) {
        console.log(`Skipping ${job.key} (id=${job.id}) due to include/exclude flags`);
        results[job.key] = { processed: 0, updated: 0, samplePaths: [] };
        continue;
      }

      if (job.type === 'collectionGroup') {
        results[job.key] = await processCollectionGroup(job.id, job.ttl, job.filter || null);
      } else {
        // top-level: check existence quickly to avoid noisy errors
        try {
          const existsSnap = await db.collection(job.id).limit(1).get();
          if (!existsSnap.empty) {
            results[job.key] = await processTopLevelCollection(job.id, job.ttl, job.filter || null);
          } else {
            results[job.key] = { processed: 0, updated: 0, samplePaths: [] };
          }
        } catch (e) {
          console.warn(`Could not query top-level collection ${job.id}:`, e.message || e);
          results[job.key] = { processed: 0, updated: 0, samplePaths: [] };
        }
      }
    }
  // Final JSON summary (include effective sample size used for wildcard expansion)
  const final = { sampleSize: SAMPLE_SIZE, results };
  console.log('Backfill complete:');
  console.log(JSON.stringify(final, null, 2));
  console.log('done');
  return results;
  } catch (err) {
    console.error('Backfill failed:', err);
    throw err;
  }
}

// Allow CLI execution and programmatic import
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch(() => process.exit(2));
}

module.exports = { main };
