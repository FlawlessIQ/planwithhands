const admin = require('firebase-admin');

// Initialize Firebase Admin with the other project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'restaurant-mgmt-app-chv29y'
  });
}

const db = admin.firestore();

async function checkOtherProject() {
  console.log('=== Checking restaurant-mgmt-app-chv29y project ===\n');
  
  try {
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    // Check if this org exists in the other project
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (orgDoc.exists) {
      console.log('✅ Found the organization in restaurant-mgmt-app-chv29y!');
      const data = orgDoc.data();
      console.log(`Name: ${data.name || 'No name'}`);
      console.log(`Timezone: ${data.timezone || 'No timezone'}`);
      console.log(`Daily Summary Settings: ${JSON.stringify(data.dailySummarySettings || 'None', null, 2)}`);
      
      // Check for users
      const usersQuery = await db.collection('organizations').doc(orgId).collection('users').limit(5).get();
      console.log(`\nUsers found: ${usersQuery.docs.length}`);
      usersQuery.docs.forEach(doc => {
        const userData = doc.data();
        console.log(`  - ${userData.email || 'No email'}: ${userData.role || 'No role'}`);
      });
      
      // Check for recent checklists
      const checklistsQuery = await db.collection('organizations').doc(orgId).collection('checklists')
        .orderBy('date', 'desc')
        .limit(5)
        .get();
      console.log(`\nRecent checklists: ${checklistsQuery.docs.length}`);
      checklistsQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.date}: ${data.locationName}`);
      });
      
    } else {
      console.log('❌ Organization not found in restaurant-mgmt-app-chv29y');
      
      // List some orgs to see what's there
      const orgsQuery = await db.collection('organizations').limit(5).get();
      console.log(`\nFound ${orgsQuery.docs.length} organizations in restaurant-mgmt-app-chv29y:`);
      orgsQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${doc.id}: ${data.name || 'No name'}`);
      });
    }
    
  } catch (error) {
    console.error('Error checking other project:', error);
  }
}

checkOtherProject().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});