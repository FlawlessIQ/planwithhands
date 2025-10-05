const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

(async () => {
  const orgId = process.argv[2];
  const locationId = process.argv[3];

  if (!orgId || !locationId) {
    console.error('Usage: node list_shifts_for_location.js <orgId> <locationId>');
    process.exit(1);
  }

  const shiftsSnap = await db.collection('organizations').doc(orgId).collection('shifts').get();
  console.log(`Shifts found: ${shiftsSnap.size}`);

  for (const doc of shiftsSnap.docs) {
    const data = doc.data() || {};
    const locIds = Array.isArray(data.locationIds) ? data.locationIds : data.locationId ? [data.locationId] : [];
    if (locIds.includes(locationId)) {
      console.log({
        shiftId: doc.id,
        checklistTemplateIds: data.checklistTemplateIds || [],
      });
    }
  }

  process.exit(0);
})();
