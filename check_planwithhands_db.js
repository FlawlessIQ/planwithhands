const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project ID and database
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
    databaseId: 'planwithhands'  // Use the named database, not (default)
  });
}

const db = admin.firestore();

async function checkCorrectDatabase() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  console.log('=== Checking planwithhands database (not default) ===\n');
  
  try {
    // Check if this org exists
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (orgDoc.exists) {
      console.log('✅ Found the organization in planwithhands database!');
      const data = orgDoc.data();
      console.log(`Name: ${data.name || 'No name'}`);
      console.log(`Timezone: ${data.timezone || 'No timezone'}`);
      console.log(`Daily Summary Settings: ${JSON.stringify(data.dailySummarySettings || 'None', null, 2)}`);
      
      // Check for users
      console.log('\n--- Users ---');
      const usersQuery = await db.collection('organizations').doc(orgId).collection('users').get();
      console.log(`Users found: ${usersQuery.docs.length}`);
      usersQuery.docs.slice(0, 5).forEach(doc => {
        const userData = doc.data();
        console.log(`  - ${userData.email || 'No email'}: ${userData.role || 'No role'} (${userData.firstName} ${userData.lastName})`);
      });
      
      // Check for recent checklists
      console.log('\n--- Recent Checklists ---');
      const checklistsQuery = await db.collection('organizations').doc(orgId).collection('checklists')
        .orderBy('date', 'desc')
        .limit(5)
        .get();
      console.log(`Recent checklists: ${checklistsQuery.docs.length}`);
      checklistsQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.date}: ${data.locationName}`);
      });
      
      // Check for tasks on recent dates
      console.log('\n--- Recent Tasks ---');
      const tasksQuery = await db.collection('organizations').doc(orgId).collection('tasks')
        .orderBy('date', 'desc')
        .limit(5)
        .get();
      console.log(`Recent tasks: ${tasksQuery.docs.length}`);
      tasksQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.date}: ${data.description} (${data.status})`);
      });
      
      // Check for locations
      console.log('\n--- Locations ---');
      const locationsQuery = await db.collection('organizations').doc(orgId).collection('locations').get();
      console.log(`Locations: ${locationsQuery.docs.length}`);
      locationsQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.name}: ${data.address || 'No address'}`);
      });
      
    } else {
      console.log('❌ Organization still not found in planwithhands database');
      
      // List some orgs to see what's there
      const orgsQuery = await db.collection('organizations').limit(10).get();
      console.log(`\nFound ${orgsQuery.docs.length} organizations in planwithhands database:`);
      orgsQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${doc.id}: ${data.name || 'No name'}`);
      });
    }
    
  } catch (error) {
    console.error('Error checking planwithhands database:', error);
  }
}

checkCorrectDatabase().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});