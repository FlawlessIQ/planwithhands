const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the same database configuration as the Cloud Function
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function triggerDailySummaryCorrectDB() {
  console.log('=== Triggering Daily Summary with Correct Database ===\n');
  
  try {
    // Use the Firebase CLI to call the function with correct parameters
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    const targetDate = '2025-09-28T00:00:00.000Z'; // Yesterday
    
    console.log(`Organization: ${orgId}`);
    console.log(`Target Date: ${targetDate}`);
    console.log(`Database: ${FIRESTORE_DATABASE_ID}`);
    
    // First, let's verify the org data one more time
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const data = orgDoc.data();
      console.log(`\nOrganization verified:`);
      console.log(`  Name: ${data.name}`);
      console.log(`  Daily Summary Settings: ${JSON.stringify(data.dailySummarySettings, null, 2)}`);
      
      // Check if there are any admin users
      const adminUsers = await db.collection('organizations').doc(orgId).collection('users')
        .where('role', '==', 'admin')
        .get();
      
      console.log(`  Admin users: ${adminUsers.docs.length}`);
      
      if (adminUsers.docs.length === 0) {
        console.log(`\n⚠️  WARNING: No admin users found!`);
        console.log(`   Daily summary function will likely skip this org because there's no one to send it to.`);
        console.log(`   The function returned 'undefined' because it has no recipients.`);
      }
      
      // Check for any data to summarize
      const hasChecklists = (await db.collection('organizations').doc(orgId).collection('checklists').limit(1).get()).docs.length > 0;
      const hasTasks = (await db.collection('organizations').doc(orgId).collection('tasks').limit(1).get()).docs.length > 0;
      
      if (!hasChecklists && !hasTasks) {
        console.log(`\n⚠️  WARNING: No checklists or tasks found!`);
        console.log(`   Daily summary function will likely skip this org because there's no data to summarize.`);
      }
      
      console.log(`\n=== Recommendation ===`);
      console.log(`To test daily summaries:`);
      console.log(`1. Add at least one admin user to the organization`);
      console.log(`2. Add some test checklists and tasks with yesterday's date`);
      console.log(`3. Then the daily summary function will have both data to summarize and recipients to send to`);
      
    } else {
      console.log('❌ Organization not found in correct database');
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

triggerDailySummaryCorrectDB().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});