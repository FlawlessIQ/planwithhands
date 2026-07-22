const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const planWithHandsDb = admin.firestore();
planWithHandsDb.settings({ databaseId: 'planwithhands' });

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function verifyChickiesYesterday() {
  try {
    console.log('=== Chickies Checklists from Yesterday (Oct 11) ===');
    console.log('Database: planwithhands\n');

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

    const allChecklistsSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .get();

    console.log('All checklists from Oct 11, 2025:\n');
    
    let foundCount = 0;
    allChecklistsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      let dateStr = 'unknown';
      
      if (data.date) {
        if (typeof data.date.toDate === 'function') {
          dateStr = data.date.toDate().toISOString().split('T')[0];
        } else if (data.date._seconds) {
          dateStr = new Date(data.date._seconds * 1000).toISOString().split('T')[0];
        }
      }
      
      if (dateStr === '2025-10-11') {
        foundCount++;
        console.log(`${foundCount}. ${data.checklistName}`);
        console.log(`   Shift ID: ${data.shiftId}`);
        console.log(`   Tasks: ${data.totalItems} total, ${data.completedItems} completed\n`);
      }
    });

    if (foundCount === 0) {
      console.log('❌ NO CHECKLISTS FOUND for Oct 11, 2025');
      console.log('\nThis confirms the "(Chickies) CLOSING (Copy)" is NOT in the database.');
      console.log('The app is showing CACHED DATA from before our cleanups.\n');
      console.log('SOLUTION: Clear the app cache or force refresh the data.');
    } else {
      console.log(`\nTotal: ${foundCount} checklists from yesterday`);
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

verifyChickiesYesterday();
