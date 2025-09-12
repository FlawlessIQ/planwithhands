// tools/cleanup/add_ttl_to_collection.ts
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldPath, Timestamp } from "firebase-admin/firestore";

type Opts = {
  path: string;
  batch: number;
  maxUpdates: number;
  sleepMsOnQuota: number;
  dryRun: boolean;
  ttlField: string;
  ttlDate: Date;
  workerId?: number;
  numWorkers?: number;
};

const args = Object.fromEntries(process.argv.slice(2).map(a => a.split("=")));

// Set TTL to midnight tonight (end of today)
const tonight = new Date();
tonight.setHours(23, 59, 59, 999); // 11:59:59.999 PM today

const opts: Opts = {
  path: args["--path"] || "organizations/vnE0olvi1Tswjtdb19MI/notifications",
  batch: Number(args["--batch"] ?? 250), // Reduced from 500 to avoid timeouts
  maxUpdates: Number(args["--maxUpdates"] ?? 1000000), // 1M default
  sleepMsOnQuota: Number(args["--sleepMsOnQuota"] ?? 15000), // Reduced backoff time
  dryRun: args["--dryRun"] === "true",
  ttlField: args["--ttlField"] || "ttlAt",
  ttlDate: args["--ttlDate"] ? new Date(args["--ttlDate"]) : tonight,
  workerId: args['--workerId'] ? Number(args['--workerId']) : undefined,
  numWorkers: args['--numWorkers'] ? Number(args['--numWorkers']) : undefined,
};

const DB = process.env.FIRESTORE_DB || "planwithhands";

const app = initializeApp({ credential: applicationDefault() });
const db = getFirestore(app, DB);

const sleep = (ms: number) => new Promise(res => setTimeout(res, ms));

(async () => {
  console.log(`Adding TTL to ${DB}/${opts.path}`);
  console.log(`TTL field: ${opts.ttlField}, expires: ${opts.ttlDate.toISOString()}`);
  console.log(`Batch: ${opts.batch}, max: ${opts.maxUpdates}, dryRun: ${opts.dryRun}`);
  
  let updated = 0;
  let cursor: string | undefined;

  // If the configured TTL date is in the past (previous run), set to the next midnight
  const now = new Date();
  if (opts.ttlDate <= now) {
    const nextMid = new Date();
    nextMid.setHours(23, 59, 59, 999);
    if (nextMid <= now) nextMid.setDate(nextMid.getDate() + 1);
    console.log(`Configured TTL (${opts.ttlDate.toISOString()}) is in the past; bumping to next midnight: ${nextMid.toISOString()}`);
    opts.ttlDate = nextMid;
  }

  const ttlTimestamp = Timestamp.fromDate(opts.ttlDate);

  while (updated < opts.maxUpdates) {
    // If sharding across workers, fetch a larger page so each worker can pick its share
    const effectiveLimit = opts.numWorkers && opts.numWorkers > 1 ? opts.batch * opts.numWorkers : opts.batch;
    let q = db.collection(opts.path)
      .orderBy(FieldPath.documentId())
      .limit(effectiveLimit);
    if (cursor) q = q.startAfter(cursor);

    const snap = await q.get();
    if (snap.empty) break;

    try {
      if (!opts.dryRun) {
        // Increased throttling for higher throughput; will still back off on errors
        const bw = db.bulkWriter({
          throttling: { initialOpsPerSecond: 300, maxOpsPerSecond: 800 },
        });

        // If sharded, only update docs that belong to this worker
        let did = 0;
        for (const doc of snap.docs) {
          let shouldUpdate = true;
          if (opts.numWorkers && opts.numWorkers > 1 && typeof opts.workerId === 'number') {
            // simple deterministic hash of doc.id
            let h = 0;
            for (let i = 0; i < doc.id.length; i++) {
              h = ((h << 5) - h) + doc.id.charCodeAt(i);
              h |= 0;
            }
            const mod = Math.abs(h) % opts.numWorkers;
            shouldUpdate = mod === opts.workerId;
          }
          if (shouldUpdate) {
            bw.update(doc.ref, { [opts.ttlField]: ttlTimestamp });
            did++;
          }
        }

        await bw.close();
        updated += did;
        console.log(`This worker updated ${did} docs in this page; total updated ${updated}`);
      } else {
        // dry run: count how many would be updated by this worker
        let would = 0;
        if (opts.numWorkers && opts.numWorkers > 1 && typeof opts.workerId === 'number') {
          for (const doc of snap.docs) {
            let h = 0;
            for (let i = 0; i < doc.id.length; i++) {
              h = ((h << 5) - h) + doc.id.charCodeAt(i);
              h |= 0;
            }
            const mod = Math.abs(h) % opts.numWorkers;
            if (mod === opts.workerId) would++;
          }
        } else {
          would = snap.size;
        }
        updated += would;
        console.log(`(dry) This worker would update ${would} docs in this page; total would ${updated}`);
      }

      // Move cursor to last doc for pagination (workers share same cursor progression)
      cursor = snap.docs[snap.docs.length - 1].id;
      
    } catch (e: any) {
      const code = e?.code || e?.status || e?.message;
      console.warn("Update error:", code);
      
      // Handle DEADLINE_EXCEEDED specifically
      if (String(code).includes("DEADLINE_EXCEEDED")) {
        console.log(`DEADLINE_EXCEEDED after ${snap.size} docs. Backing off for ${opts.sleepMsOnQuota}ms...`);
        await sleep(opts.sleepMsOnQuota);
        continue; // Don't increment cursor, retry same batch
      }
      
      if (String(code).includes("RESOURCE_EXHAUSTED") ||
          String(code).includes("UNAVAILABLE")) {
        console.log(`Backing off for ${opts.sleepMsOnQuota}ms...`);
        await sleep(opts.sleepMsOnQuota);
        continue;
      }
      throw e;
    }
  }

  console.log(opts.dryRun
    ? `DRY RUN complete (would add TTL to ${updated} docs).`
    : `Done. Added TTL to ${updated} docs this run.`);
  
  if (!opts.dryRun) {
    console.log(`Documents will auto-expire at: ${opts.ttlDate.toISOString()}`);
    console.log("Note: You still need to enable TTL policy in Firestore Console for the collection.");
  }
  
  process.exit(0);
})();
