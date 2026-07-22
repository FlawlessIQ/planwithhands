const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

(async () => {
  const orgId = process.argv[2];
  if (!orgId) {
    console.error('Usage: node list_locations_for_org.js <orgId>');
    process.exit(1);
  }

  const snap = await db.collection('organizations').doc(orgId).collection('locations').get();
  console.log(`Locations for ${orgId}: ${snap.size}`);
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    console.log({id: doc.id, name: data.name, timezone: data.timezone});
  }
  process.exit(0);
})();
