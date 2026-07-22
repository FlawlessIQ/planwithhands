const { Firestore } = require('@google-cloud/firestore');

const db = new Firestore({ databaseId: 'planwithhands' });

const orgId = process.argv[2];
const locId = process.argv[3];
const date = process.argv[4];

(async () => {
  if (!orgId || !locId) {
    console.error('Usage: node list_checklists_for_location.js <orgId> <locId> [date]');
    process.exit(1);
  }

  const ref = db.collection('organizations').doc(orgId).collection('locations').doc(locId).collection('daily_checklists');
  let query = ref;
  if (date) {
    query = query.where('date', '==', date);
  }
  query = query.orderBy('date', 'desc').limit(20);

  const snap = await query.get();
  console.log('Found', snap.size, 'checklists');
  for (const doc of snap.docs) {
    console.log('id:', doc.id, 'date:', doc.get('date'), 'templateName:', doc.get('templateName'), 'templateIds:', doc.get('checklistTemplateIds'));
  }
})();
