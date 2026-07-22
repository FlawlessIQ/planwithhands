const { Firestore } = require('@google-cloud/firestore');

const db = new Firestore({ databaseId: 'planwithhands' });

const docPath = process.argv[2];

if (!docPath) {
  console.error('Usage: node inspect_checklist_doc.js <docPath>');
  process.exit(1);
}

(async () => {
  try {
    const doc = await db.doc(docPath).get();
    if (!doc.exists) {
      console.log('Document not found:', docPath);
    } else {
      console.log('Document:', docPath);
      console.log(JSON.stringify(doc.data(), null, 2));
    }
  } catch (err) {
    console.error('Error reading doc:', err);
  }
})();
