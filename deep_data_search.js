const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function deepDataSearch() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  console.log('=== Deep Data Search ===\n');
  
  try {
    // Check for any data in the last 90 days
    const threeMonthsAgo = new Date();
    threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
    
    console.log(`Searching from ${threeMonthsAgo.toISOString()} to now...\n`);
    
    // Check checklists
    const checklistsRef = db.collection('organizations').doc(orgId).collection('checklists');
    const allChecklists = await checklistsRef.get();
    console.log(`Total checklists ever: ${allChecklists.docs.length}`);
    
    // Check tasks  
    const tasksRef = db.collection('organizations').doc(orgId).collection('tasks');
    const allTasks = await tasksRef.get();
    console.log(`Total tasks ever: ${allTasks.docs.length}`);
    
    // Check users
    const usersRef = db.collection('organizations').doc(orgId).collection('users');
    const allUsers = await usersRef.get();
    console.log(`Total users ever: ${allUsers.docs.length}`);
    
    // Check locations
    const locationsRef = db.collection('organizations').doc(orgId).collection('locations');
    const allLocations = await locationsRef.get();
    console.log(`Total locations ever: ${allLocations.docs.length}`);
    
    // Check daily summaries
    const summariesRef = db.collection('organizations').doc(orgId).collection('dailySummaries');
    const allSummaries = await summariesRef.get();
    console.log(`Total daily summaries ever: ${allSummaries.docs.length}`);
    
    // Let's also check if there are organizations with actual data
    console.log('\n=== Organizations with data ===');
    const allOrgs = await db.collection('organizations').get();
    
    for (const orgDoc of allOrgs.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      
      // Quick check for any users in this org
      const usersSnapshot = await db.collection('organizations').doc(orgId).collection('users').limit(1).get();
      const checklistsSnapshot = await db.collection('organizations').doc(orgId).collection('checklists').limit(1).get();
      
      if (usersSnapshot.docs.length > 0 || checklistsSnapshot.docs.length > 0) {
        console.log(`\nOrg ${orgId}:`);
        console.log(`  Name: ${orgData.name || 'No name'}`);
        console.log(`  Has users: ${usersSnapshot.docs.length > 0 ? 'Yes' : 'No'}`);
        console.log(`  Has checklists: ${checklistsSnapshot.docs.length > 0 ? 'Yes' : 'No'}`);
        console.log(`  Daily summary settings: ${JSON.stringify(orgData.dailySummarySettings || 'None')}`);
      }
    }
    
  } catch (error) {
    console.error('Error in deep search:', error);
  }
}

deepDataSearch().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});