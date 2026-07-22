const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
  });
}

const db = admin.firestore(undefined, 'planwithhands');

const docPath = process.argv[2];

if (!docPath) {
  console.error('Usage: node fetch_single_doc.js <docPath>');
  process.exit(1);
}

(async () => {
  try {
    const snap = await db.doc(docPath).get();
    if (!snap.exists) {
      console.log('not found');
    } else {
      console.log(JSON.stringify(snap.data(), null, 2));
    }
  } catch (err) {
    console.error('Error:', err);
  }
})();
