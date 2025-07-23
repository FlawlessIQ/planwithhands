/**
 * Export Firestore data (including subcollections) to a JSON file.
 * Run: `node exportFirestore.js`
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./serviceAccountKey-old.json'); // Replace with your old project's key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportCollection(collectionRef) {
  const data = {};
  const snapshot = await collectionRef.get();

  for (const doc of snapshot.docs) {
    const docData = doc.data();
    const subcollections = await doc.ref.listCollections();
    const subData = {};

    for (const sub of subcollections) {
      subData[sub.id] = await exportCollection(sub);
    }

    data[doc.id] = { ...docData, _subcollections: subData };
  }

  return data;
}

async function main() {
  const rootCollections = await db.listCollections();
  const exportData = {};

  for (const col of rootCollections) {
    console.log(`Exporting collection: ${col.id}`);
    exportData[col.id] = await exportCollection(col);
  }

  fs.writeFileSync('firestore_export.json', JSON.stringify(exportData, null, 2));
  console.log('Export complete -> firestore_export.json');
}

main();
