#!/usr/bin/env node
// Backfill missing expiresAt fields for ephemeral collections
// Usage: node functions/scripts/backfillExpiresAt.js

const admin = require('firebase-admin');
const path = require('path');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const BATCH_SIZE = 500;
const TTL_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

async function processCollection(collPath, isCollectionGroup = false) {
  console.log(`Scanning ${collPath} (collectionGroup=${isCollectionGroup})`);
  let processed = 0;
  let updated = 0;
  const now = Date.now();
  const expireDate = new Date(now + TTL_MS);

  const iterator = isCollectionGroup
    ? db.collectionGroup(collPath).listDocuments()
    : db.collection(collPath).listDocuments();

  // listDocuments returns an array of DocumentReference when called on collectionGroup? Not supported.
  // For collectionGroup we need to use query snapshots. So handle separately.
  if (isCollectionGroup) {
    const q = db.collectionGroup(collPath);
    const pageSize = 1000;
    let last = null;
    while (true) {
      let query = q.limit(pageSize);
      if (last) query = query.startAfter(last);
      const snap = await query.get();
      if (snap.empty) break;
      let batch = db.batch();
      let batchOps = 0;
      for (const doc of snap.docs) {
        processed++;
        const data = doc.data();
        if (!data || data.expiresAt) continue;
        batch.update(doc.ref, { expiresAt: admin.firestore.Timestamp.fromDate(expireDate) });
        batchOps++;
        updated++;
        if (batchOps >= BATCH_SIZE) {
          await batch.commit();
          batch = db.batch();
          batchOps = 0;
        }
      }
      if (batchOps > 0) await batch.commit();
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < pageSize) break;
    }
  } else {
    const snap = await db.collection(collPath).listDocuments();
    // listDocuments returns array
    let docs = snap;
    let i = 0;
    while (i < docs.length) {
      const batch = db.batch();
      let ops = 0;
      for (let j = 0; j < BATCH_SIZE && i < docs.length; j++, i++) {
        const docRef = docs[i];
        processed++;
        // Need to fetch doc to check existing fields
        // We'll fetch by docRef.get() in micro-batches
        const d = await docRef.get();
        const data = d.data();
        if (!data || data.expiresAt) continue;
        batch.update(docRef, { expiresAt: admin.firestore.Timestamp.fromDate(expireDate) });
        ops++;
        updated++;
      }
      if (ops > 0) await batch.commit();
    }
  }

  console.log(`Scanned ${collPath}: processed=${processed}, updated=${updated}`);
  return { processed, updated };
}

async function main() {
  try {
    // Collections: daily_checklists (root and organization-scoped), tasks subcollections (collectionGroup 'tasks'), invites, notifications
    // We'll scan collectionGroup 'daily_checklists' to find org/location scoped docs
    const results = {};

    // 1) daily_checklists collectionGroup
    results.daily_checklists = await processCollection('daily_checklists', true);

    // 2) tasks subcollection (collectionGroup 'tasks') - careful: this matches many tasks; we filter by fields to only update checklist tasks
    // We'll scan collectionGroup 'tasks' and only update docs that have 'checklistId' or 'dailyChecklistId' or 'organizationId' fields
    console.log('Scanning collectionGroup: tasks (filtered)');
    let processed = 0;
    let updated = 0;
    const pageSize = 1000;
    let last = null;
    const qBase = db.collectionGroup('tasks');
    while (true) {
      let q = qBase.limit(pageSize);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      let batch = db.batch();
      let batchOps = 0;
      for (const doc of snap.docs) {
        processed++;
        const data = doc.data() || {};
        // Simple heuristic: if doc has checklistId or dailyChecklistId or isCarryForward field then it's a checklist task
        if (!data || data.expiresAt) continue;
        if (!(data.checklistId || data.dailyChecklistId || data.organizationId || data.isCarryForward)) continue;
        batch.update(doc.ref, { expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + TTL_MS)) });
        batchOps++;
        updated++;
        if (batchOps >= BATCH_SIZE) {
          await batch.commit();
          batch = db.batch();
          batchOps = 0;
        }
      }
      if (batchOps > 0) await batch.commit();
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < pageSize) break;
    }
    results.tasks = { processed, updated };
    console.log(`Scanned tasks collectionGroup: processed=${processed}, updated=${updated}`);

    // 3) invites collection (root)
    results.invites = await processCollection('invites', false);

    // 4) notifications (organization-scoped) - scan collectionGroup 'notifications'
    results.notifications = await processCollection('notifications', true);

    console.log('Backfill complete:', results);
    process.exit(0);
  } catch (err) {
    console.error('Backfill failed:', err);
    process.exit(2);
  }
}

main();
