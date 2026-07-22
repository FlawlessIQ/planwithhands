const admin = require('firebase-admin');

// Initialize Firebase Admin (it should use the default credentials)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function debugDailySummaryData() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const targetDate = '2025-09-28';
  
  console.log(`=== Daily Summary Debug for Org: ${orgId}, Date: ${targetDate} ===\n`);
  
  try {
    // 1. Check organization data
    console.log('1. Organization Data:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      console.log('   Organization exists:', orgDoc.data().name || 'No name');
      console.log('   Daily summary settings:', orgDoc.data().dailySummarySettings || 'Not configured');
    } else {
      console.log('   ERROR: Organization not found!');
      return;
    }
    
    // 2. Check locations
    console.log('\n2. Locations:');
    const locationsQuery = await db.collection('organizations').doc(orgId).collection('locations').get();
    console.log(`   Found ${locationsQuery.docs.length} locations`);
    
    // 3. Check checklists for target date
    console.log(`\n3. Checklists for ${targetDate}:`);
    const checklistsQuery = await db.collection('organizations').doc(orgId).collection('checklists')
      .where('date', '>=', `${targetDate}T00:00:00`)
      .where('date', '<', `${targetDate}T23:59:59`)
      .get();
    console.log(`   Found ${checklistsQuery.docs.length} checklists`);
    
    if (checklistsQuery.docs.length > 0) {
      checklistsQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`   - Checklist ${doc.id}: ${data.locationName}, Date: ${data.date}`);
      });
    }
    
    // 4. Check tasks for target date  
    console.log(`\n4. Tasks for ${targetDate}:`);
    const tasksQuery = await db.collection('organizations').doc(orgId).collection('tasks')
      .where('date', '>=', `${targetDate}T00:00:00`)
      .where('date', '<', `${targetDate}T23:59:59`)
      .get();
    console.log(`   Found ${tasksQuery.docs.length} tasks`);
    
    if (tasksQuery.docs.length > 0) {
      tasksQuery.docs.slice(0, 5).forEach(doc => {
        const data = doc.data();
        console.log(`   - Task ${doc.id}: ${data.description} (${data.status})`);
      });
      if (tasksQuery.docs.length > 5) {
        console.log(`   ... and ${tasksQuery.docs.length - 5} more tasks`);
      }
    }
    
    // 5. Check admin users
    console.log('\n5. Admin Users:');
    const usersQuery = await db.collection('organizations').doc(orgId).collection('users')
      .where('role', '==', 'admin')
      .get();
    console.log(`   Found ${usersQuery.docs.length} admin users`);
    
    if (usersQuery.docs.length > 0) {
      usersQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`   - Admin: ${data.email || 'No email'} (${data.firstName} ${data.lastName})`);
      });
    }
    
    // 6. Check existing daily summaries
    console.log('\n6. Existing Daily Summaries:');
    const summariesQuery = await db.collection('organizations').doc(orgId).collection('dailySummaries')
      .orderBy('date', 'desc')
      .limit(5)
      .get();
    console.log(`   Found ${summariesQuery.docs.length} recent daily summaries`);
    
    if (summariesQuery.docs.length > 0) {
      summariesQuery.docs.forEach(doc => {
        const data = doc.data();
        console.log(`   - Summary: ${data.date} (${data.completedTasks || 0} completed, ${data.missedTasks || 0} missed)`);
      });
    }
    
    console.log('\n=== Debug Complete ===');
    
  } catch (error) {
    console.error('Error debugging data:', error);
  }
}

debugDailySummaryData().then(() => {
  console.log('Done.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});