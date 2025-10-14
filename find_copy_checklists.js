const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const planWithHandsDb = admin.firestore();
planWithHandsDb.settings({ databaseId: 'planwithhands' });

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function findCopyChecklists() {
  try {
    console.log('=== Searching for any "(Copy)" checklists ===');
    console.log('Database: planwithhands\n');

    // Get Chickies location
    const locationsSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .get();

    let chickiesLocationId = null;
    for (const locDoc of locationsSnapshot.docs) {
      const locData = locDoc.data();
      if (locData.name === 'Chickies') {
        chickiesLocationId = locDoc.id;
        break;
      }
    }

    // Get ALL checklists and search for "Copy"
    const allChecklistsSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .get();

    console.log(`Total checklists in Chickies: ${allChecklistsSnapshot.size}\n`);
    console.log('Checklists containing "Copy":\n');

    let foundCount = 0;
    allChecklistsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.checklistName && data.checklistName.includes('Copy')) {
        foundCount++;
        const dateStr = data.date ? data.date.toDate().toISOString().split('T')[0] : 'unknown';
        console.log(`${foundCount}. ${data.checklistName}`);
        console.log(`   ID: ${doc.id}`);
        console.log(`   Date: ${dateStr}`);
        console.log(`   Shift ID: ${data.shiftId}`);
        console.log(`   Tasks: ${data.totalItems} total, ${data.completedItems} completed\n`);
      }
    });

    if (foundCount === 0) {
      console.log('No checklists found with "(Copy)" in the name.');
      console.log('\nShowing recent checklists from Oct 10-12:\n');
      
      allChecklistsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        if (data.date) {
          const dateStr = data.date.toDate().toISOString().split('T')[0];
          if (dateStr >= '2025-10-10' && dateStr <= '2025-10-12') {
            console.log(`- ${data.checklistName} (${dateStr})`);
          }
        }
      });
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

findCopyChecklists();
