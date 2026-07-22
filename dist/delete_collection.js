"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
// tools/cleanup/delete_collection.ts
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const args = Object.fromEntries(process.argv.slice(2).map(a => a.split("=")));
const opts = {
    path: args["--path"] || "organizations/vnE0olvi1Tswjtdb19MI/notifications",
    batch: Number(args["--batch"] ?? 500),
    maxDeletes: Number(args["--maxDeletes"] ?? 50000),
    sleepMsOnQuota: Number(args["--sleepMsOnQuota"] ?? 60000),
    dryRun: args["--dryRun"] === "true",
};
const DB = process.env.FIRESTORE_DB || "planwithhands";
const app = (0, app_1.initializeApp)({ credential: (0, app_1.applicationDefault)() });
const db = (0, firestore_1.getFirestore)(app, DB);
const sleep = (ms) => new Promise(res => setTimeout(res, ms));
(async () => {
    console.log(`Deleting from ${DB}/${opts.path} (batch=${opts.batch}, cap=${opts.maxDeletes}, dryRun=${opts.dryRun})`);
    let deleted = 0;
    let cursor;
    while (deleted < opts.maxDeletes) {
        let q = db.collection(opts.path)
            .orderBy(firestore_1.FieldPath.documentId())
            .limit(opts.batch);
        if (cursor)
            q = q.startAfter(cursor);
        const snap = await q.get();
        if (snap.empty)
            break;
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
        }
        catch (e) {
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
