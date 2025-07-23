/**
 * Import Firestore data from JSON file.
 * Run: `node importFirestore.js`
 */

const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey-new.json'); // Replace with your new project's key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const data = JSON.parse(fs.readFileSync('firestore_export.json', 'utf8'));

async function importCollection(colRef, docs) {
  for (const [docId, docData] of Object.entries(docs)) {
    const { _subcollections, ...fields } = docData;
    await colRef.doc(docId).set(fields);
    console.log(`Imported doc: ${colRef.id}/${docId}`);

    if (_subcollections) {
      for (const [subId, subDocs] of Object.entries(_subcollections)) {
        await importCollection(colRef.doc(docId).collection(subId), subDocs);
      }
    }
  }
}

async function main() {
  for (const [collectionName, docs] of Object.entries(data)) {
    await importCollection(db.collection(collectionName), docs);
  }

  console.log('Import complete.');
}

main();
