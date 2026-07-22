// tools/cleanup/delete_collection.ts
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldPath } from "firebase-admin/firestore";

type Opts = {
  path: string;
  batch: number;
  maxDeletes: number;
  sleepMsOnQuota: number;
  dryRun: boolean;
};
const args = Object.fromEntries(process.argv.slice(2).map(a => a.split("=")));
const opts: Opts = {
  path: args["--path"] || "organizations/vnE0olvi1Tswjtdb19MI/notifications",
  batch: Number(args["--batch"] ?? 500),
  maxDeletes: Number(args["--maxDeletes"] ?? 50000),
  sleepMsOnQuota: Number(args["--sleepMsOnQuota"] ?? 60000),
  dryRun: args["--dryRun"] === "true",
};

const DB = process.env.FIRESTORE_DB || "planwithhands";

import { getApp } from "firebase-admin/app";
const app = initializeApp({ credential: applicationDefault() });
const db = getFirestore(app, DB);

const sleep = (ms: number) => new Promise(res => setTimeout(res, ms));

(async () => {
  console.log(`Deleting from ${DB}/${opts.path} (batch=${opts.batch}, cap=${opts.maxDeletes}, dryRun=${opts.dryRun})`);
  let deleted = 0;
  let cursor: string | undefined;

  while (deleted < opts.maxDeletes) {
    let q = db.collection(opts.path)
      .orderBy(FieldPath.documentId())
      .limit(opts.batch);
    if (cursor) q = q.startAfter(cursor);

    const snap = await q.get();
    if (snap.empty) break;

    try {
      if (!opts.dryRun) {
        const bw = db.bulkWriter({
          throttling: { initialOpsPerSecond: 200, maxOpsPerSecond: 500 },
        });
        snap.docs.forEach(d => bw.delete(d.ref));
        await bw.close();
      }
      deleted += snap.size;
      cursor = snap.docs[snap.docs.length - 1].id;
      console.log(`Deleted ${deleted} so far...`);
    } catch (e: any) {
      const code = e?.code || e?.status || e?.message;
      console.warn("Write error:", code);
      // Common transient or quota cases: RESOURCE_EXHAUSTED, DEADLINE_EXCEEDED, UNAVAILABLE
      if (String(code).includes("RESOURCE_EXHAUSTED") ||
          String(code).includes("DEADLINE_EXCEEDED") ||
          String(code).includes("UNAVAILABLE")) {
        console.log(`Backing off for ${opts.sleepMsOnQuota}ms...`);
        await sleep(opts.sleepMsOnQuota);
        continue;
      }
      throw e; // unknown error → stop
    }
  }

  console.log(opts.dryRun
    ? `DRY RUN complete (would delete up to ${deleted} docs).`
    : `Done. Deleted ${deleted} docs this run.`);
  process.exit(0);
})();
