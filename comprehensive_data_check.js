const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the same database configuration as the Cloud Function
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function findActualData() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  console.log(`=== Comprehensive search for ${orgId} in ${FIRESTORE_DATABASE_ID} database ===\n`);
  
  try {
    // Check organization data
    console.log('1. Organization Data:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const data = orgDoc.data();
      console.log(`   ✅ Organization exists`);
      console.log(`   Name: ${data.name || 'No name'}`);
      console.log(`   Timezone: ${data.timezone || 'No timezone'}`);
      console.log(`   Daily Summary Settings: ${JSON.stringify(data.dailySummarySettings || 'None', null, 2)}`);
    } else {
      console.log('   ❌ Organization not found');
      return;
    }
    
    // Check for any data at all (no date filters)
    console.log('\n2. All Historical Data:');
    
    // Check all checklists
    const allChecklists = await db.collection('organizations').doc(orgId).collection('checklists').get();
    console.log(`   Checklists (all time): ${allChecklists.docs.length}`);
    
    if (allChecklists.docs.length > 0) {
      console.log('   Recent checklists:');
      allChecklists.docs.slice(0, 5).forEach(doc => {
        const data = doc.data();
        console.log(`     - ${data.date}: ${data.locationName} (${doc.id})`);
      });
      if (allChecklists.docs.length > 5) {
        console.log(`     ... and ${allChecklists.docs.length - 5} more`);
      }
    }
    
    // Check all tasks
    const allTasks = await db.collection('organizations').doc(orgId).collection('tasks').get();
    console.log(`\n   Tasks (all time): ${allTasks.docs.length}`);
    
    if (allTasks.docs.length > 0) {
      console.log('   Recent tasks:');
      allTasks.docs.slice(0, 5).forEach(doc => {
        const data = doc.data();
        console.log(`     - ${data.date}: ${data.description} (${data.status})`);
      });
      if (allTasks.docs.length > 5) {
        console.log(`     ... and ${allTasks.docs.length - 5} more`);
      }
    }
    
    // Check all users
    const allUsers = await db.collection('organizations').doc(orgId).collection('users').get();
    console.log(`\n   Users (all time): ${allUsers.docs.length}`);
    
    if (allUsers.docs.length > 0) {
      console.log('   All users:');
      allUsers.docs.forEach(doc => {
        const data = doc.data();
        console.log(`     - ${data.email || 'No email'}: ${data.role || 'No role'} (${data.firstName} ${data.lastName})`);
      });
    }
    
    // Check all locations
    const allLocations = await db.collection('organizations').doc(orgId).collection('locations').get();
    console.log(`\n   Locations (all time): ${allLocations.docs.length}`);
    
    if (allLocations.docs.length > 0) {
      console.log('   All locations:');
      allLocations.docs.forEach(doc => {
        const data = doc.data();
        console.log(`     - ${data.name}: ${data.address || 'No address'}`);
      });
    }
    
    // Check for existing daily summaries
    const allSummaries = await db.collection('organizations').doc(orgId).collection('dailySummaries').get();
    console.log(`\n   Daily Summaries (all time): ${allSummaries.docs.length}`);
    
    if (allSummaries.docs.length > 0) {
      console.log('   Existing summaries:');
      allSummaries.docs.forEach(doc => {
        const data = doc.data();
        console.log(`     - ${data.date}: ${data.completedTasks || 0} completed, ${data.missedTasks || 0} missed`);
      });
    }
    
    console.log('\n=== SUMMARY ===');
    const hasAnyData = allChecklists.docs.length > 0 || allTasks.docs.length > 0 || allUsers.docs.length > 0 || allLocations.docs.length > 0;
    console.log(`Has any data: ${hasAnyData ? '✅ YES' : '❌ NO'}`);
    
    if (!hasAnyData) {
      console.log('\nThis organization is completely empty - no data to send daily summaries for!');
      console.log('Daily summary function would correctly skip this organization.');
    }
    
  } catch (error) {
    console.error('Error in comprehensive search:', error);
  }
}

findActualData().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});