const admin = require('firebase-admin');

// Initialize with NO firestore calls yet
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

// NOW get firestore and set database ID BEFORE any other calls
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function searchClosingCopy() {
  try {
    console.log('=== Searching for CLOSING (Copy) in PLANWITHHANDS database ===\n');
    
    // Get locations
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .get();
    
    console.log(`Found ${locationsSnapshot.size} locations\n`);
    
    let chickiesId = null;
    for (const locDoc of locationsSnapshot.docs) {
      const locData = locDoc.data();
      console.log(`- ${locData.name}`);
      if (locData.name === 'Chickies') {
        chickiesId = locDoc.id;
      }
    }
    
    if (!chickiesId) {
      console.log('Chickies not found!');
      return;
    }
    
    console.log(`\nSearching Chickies (${chickiesId}) for "(Copy)" checklists...\n`);
    
    // Get ALL checklists
    const allChecklists = await db
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .doc(chickiesId)
      .collection('daily_checklists')
      .get();
    
    console.log(`Total checklists: ${allChecklists.size}\n`);
    
    let copyFound = false;
    allChecklists.docs.forEach(doc => {
      const data = doc.data();
      if (data.checklistName && data.checklistName.toLowerCase().includes('copy')) {
        copyFound = true;
        console.log('✓ FOUND:');
        console.log(`  Name: ${data.checklistName}`);
        console.log(`  ID: ${doc.id}`);
        console.log(`  Shift ID: ${data.shiftId}`);
        console.log(`  Tasks: ${data.totalItems}`);
        
        // Try to get date
        if (data.date && data.date.toDate) {
          console.log(`  Date: ${data.date.toDate().toISOString().split('T')[0]}`);
        } else if (data.date && data.date._seconds) {
          const dateStr = new Date(data.date._seconds * 1000).toISOString().split('T')[0];
          console.log(`  Date: ${dateStr}`);
        }
        console.log('');
      }
    });
    
    if (!copyFound) {
      console.log('❌ No checklists with "Copy" found in Chickies');
      console.log('\nShowing first 5 checklists as sample:');
      allChecklists.docs.slice(0, 5).forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.checklistName}`);
      });
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

searchClosingCopy();
