// tools/cleanup/count_collection.ts
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const DB = process.env.FIRESTORE_DB || "planwithhands";
const PATH = process.argv[2];

if (!PATH) {
  console.error("Usage: ts-node tools/cleanup/count_collection.ts organizations/ORG_ID/notifications");
  process.exit(1);
}

import { getApp } from "firebase-admin/app";
const app = initializeApp({ credential: applicationDefault() });
const db = getFirestore(app, DB);

(async () => {
  const res = await db.collection(PATH).count().get();
  console.log(`COUNT ${DB}/${PATH}:`, res.data().count);
})();
