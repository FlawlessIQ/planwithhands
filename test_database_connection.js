const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

async function testDatabaseConnection() {
  try {
    console.log('=== Testing Database Connections ===\n');
    
    // Test default database
    console.log('1. Testing DEFAULT database:');
    const defaultDb = admin.firestore();
    const defaultOrgs = await defaultDb.collection('organizations').doc('FErQ4pkcrCovJ7T6L13M').get();
    console.log(`   Org exists in default: ${defaultOrgs.exists}\n`);
    
    // Test planwithhands database
    console.log('2. Testing PLANWITHHANDS database:');
    const planDb = admin.firestore();
    planDb.settings({ databaseId: 'planwithhands' });
    const planOrgs = await planDb.collection('organizations').doc('FErQ4pkcrCovJ7T6L13M').get();
    console.log(`   Org exists in planwithhands: ${planOrgs.exists}\n`);
    
    if (planOrgs.exists) {
      // Get locations
      const locationsSnapshot = await planDb
        .collection('organizations')
        .doc('FErQ4pkcrCovJ7T6L13M')
        .collection('locations')
        .get();
      
      console.log(`3. Found ${locationsSnapshot.size} locations\n`);
      
      for (const locDoc of locationsSnapshot.docs) {
        const locData = locDoc.data();
        console.log(`   - ${locData.name} (${locDoc.id})`);
        
        if (locData.name === 'Chickies') {
          // Get ALL checklists for Chickies
          const checklistsSnapshot = await planDb
            .collection('organizations')
            .doc('FErQ4pkcrCovJ7T6L13M')
            .collection('locations')
            .doc(locDoc.id)
            .collection('daily_checklists')
            .limit(10)
            .get();
          
          console.log(`\n4. Sample of ${checklistsSnapshot.size} checklists from Chickies:`);
          checklistsSnapshot.docs.forEach(doc => {
            const data = doc.data();
            console.log(`   - ${data.checklistName}`);
            console.log(`     ID: ${doc.id}`);
            console.log(`     Has 'Copy': ${data.checklistName?.includes('Copy') || false}`);
          });
        }
      }
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

testDatabaseConnection();
