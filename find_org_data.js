const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function findOrgData() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  console.log(`=== Finding ANY data for Org: ${orgId} ===\n`);
  
  try {
    // Check for any checklists (last 30 days)
    console.log('1. Recent Checklists (last 30 days):');
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0];
    
    const checklistsQuery = await db.collection('organizations').doc(orgId).collection('checklists')
      .where('date', '>=', `${thirtyDaysAgoStr}T00:00:00`)
      .orderBy('date', 'desc')
      .limit(10)
      .get();
    
    console.log(`   Found ${checklistsQuery.docs.length} checklists in last 30 days`);
    checklistsQuery.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.date}: ${data.locationName}`);
    });
    
    // Check for any tasks (last 30 days)
    console.log('\n2. Recent Tasks (last 30 days):');
    const tasksQuery = await db.collection('organizations').doc(orgId).collection('tasks')
      .where('date', '>=', `${thirtyDaysAgoStr}T00:00:00`)
      .orderBy('date', 'desc')
      .limit(10)
      .get();
    
    console.log(`   Found ${tasksQuery.docs.length} tasks in last 30 days`);
    tasksQuery.docs.slice(0, 5).forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.date}: ${data.description} (${data.status})`);
    });
    
    // Check for any users
    console.log('\n3. All Users:');
    const usersQuery = await db.collection('organizations').doc(orgId).collection('users').get();
    console.log(`   Found ${usersQuery.docs.length} total users`);
    usersQuery.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.email || 'No email'}: ${data.role || 'No role'} (${data.firstName} ${data.lastName})`);
    });
    
    // Check if this is truly a "dummy" org with test data
    console.log('\n4. Organization details:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log('   Full org data:', JSON.stringify(orgData, null, 2));
    }
    
    console.log('\n=== Search Complete ===');
    
  } catch (error) {
    console.error('Error searching data:', error);
  }
}

findOrgData().then(() => {
  console.log('Done.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});