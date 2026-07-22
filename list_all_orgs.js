const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function listAllOrganizations() {
  console.log('=== Listing all organizations in plan-with-hands database ===\n');
  
  try {
    const orgsQuery = await db.collection('organizations').limit(10).get();
    
    console.log(`Found ${orgsQuery.docs.length} organizations:`);
    
    orgsQuery.docs.forEach(doc => {
      const data = doc.data();
      console.log(`\nOrg ID: ${doc.id}`);
      console.log(`  Name: ${data.name || 'No name'}`);
      console.log(`  Timezone: ${data.timezone || 'No timezone'}`);
      console.log(`  Daily Summary Settings: ${JSON.stringify(data.dailySummarySettings || 'None')}`);
      console.log(`  Updated: ${data.updatedAt ? new Date(data.updatedAt.toDate()).toISOString() : 'Unknown'}`);
    });
    
    // Also try to find org 3qjYzHagWmfbnMieJ1aj specifically
    console.log('\n=== Specific org lookup ===');
    const specificOrg = await db.collection('organizations').doc('3qjYzHagWmfbnMieJ1aj').get();
    if (specificOrg.exists) {
      console.log('Found the specific org in this database!');
      const data = specificOrg.data();
      console.log('Settings:', JSON.stringify(data.dailySummarySettings, null, 2));
    } else {
      console.log('The specific org 3qjYzHagWmfbnMieJ1aj was NOT found in this database!');
    }
    
  } catch (error) {
    console.error('Error listing organizations:', error);
  }
}

listAllOrganizations().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});