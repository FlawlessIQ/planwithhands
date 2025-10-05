const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const docPath = process.argv[2];

(async () => {
  try {
    const snap = await db.doc(docPath).get();
    if (!snap.exists) {
      console.log('not found in default');
    } else {
      console.log(JSON.stringify(snap.data(), null, 2));
    }
  } catch (err) {
    console.error('Error:', err);
  }
})();
