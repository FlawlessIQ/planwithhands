const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

(async () => {
  const orgId = process.argv[2];
  const locationId = process.argv[3];
  const date = process.argv[4];

  if (!orgId || !locationId || !date) {
    console.error('Usage: node check_daily_checklists_sample.js <orgId> <locationId> <YYYY-MM-DD>');
    process.exit(1);
  }

  const snap = await db.collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', date)
    .get();

  console.log(`Found ${snap.size} checklists`);
  for (const doc of snap.docs) {
    const data = doc.data();
    console.log({
      id: doc.id,
      templateName: data.templateName,
      templateNames: data.templateNames,
      checklistTemplateIds: data.checklistTemplateIds,
    });
  }

  process.exit(0);
})();
