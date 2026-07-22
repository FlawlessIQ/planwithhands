const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

const targetDate = process.argv[2];
if (!targetDate) {
  console.error('Usage: node delete_daily_checklists_for_date.js YYYY-MM-DD');
  process.exit(1);
}

(async () => {
  console.log(`Deleting daily_checklists for date ${targetDate}`);
  const orgsSnap = await db.collection('organizations').get();
  let deleted = 0;

  for (const orgDoc of orgsSnap.docs) {
    const orgId = orgDoc.id;
    const locationsSnap = await db.collection('organizations').doc(orgId).collection('locations').get();

    for (const locDoc of locationsSnap.docs) {
      const locationId = locDoc.id;
      const checklistsSnap = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', targetDate)
        .get();

      for (const checklistDoc of checklistsSnap.docs) {
        const checklistRef = checklistDoc.ref;
        const tasksSnap = await checklistRef.collection('tasks').get();
        if (!tasksSnap.empty) {
          const taskBatch = db.batch();
          for (const taskDoc of tasksSnap.docs) {
            taskBatch.delete(taskDoc.ref);
          }
          await taskBatch.commit();
        }

        await checklistRef.delete();
        deleted++;
        console.log(`Deleted checklist ${checklistRef.path}`);
      }
    }
  }

  console.log(`Deleted ${deleted} checklists for ${targetDate}`);
  process.exit(0);
})();
