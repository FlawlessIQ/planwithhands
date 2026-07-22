const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project ID and database
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
    databaseId: 'planwithhands'  // Use the named database, not (default)
  });
}

const db = admin.firestore();

async function findOrgsWithData() {
  console.log('=== Finding organizations with actual data in planwithhands database ===\n');
  
  try {
    const orgsQuery = await db.collection('organizations').get();
    console.log(`Found ${orgsQuery.docs.length} total organizations\n`);
    
    for (const orgDoc of orgsQuery.docs) {
      const orgData = orgDoc.data();
      const orgId = orgDoc.id;
      
      // Check for users
      const usersSnapshot = await db.collection('organizations').doc(orgId).collection('users').limit(1).get();
      const usersCount = usersSnapshot.docs.length;
      
      // Check for checklists
      const checklistsSnapshot = await db.collection('organizations').doc(orgId).collection('checklists').limit(1).get();
      const checklistsCount = checklistsSnapshot.docs.length;
      
      // Check for tasks
      const tasksSnapshot = await db.collection('organizations').doc(orgId).collection('tasks').limit(1).get();
      const tasksCount = tasksSnapshot.docs.length;
      
      // Check for locations
      const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').limit(1).get();
      const locationsCount = locationsSnapshot.docs.length;
      
      const hasData = usersCount > 0 || checklistsCount > 0 || tasksCount > 0 || locationsCount > 0;
      
      if (hasData) {
        console.log(`Org ${orgId}:`);
        console.log(`  Name: ${orgData.name || 'No name'}`);
        console.log(`  Timezone: ${orgData.timezone || 'No timezone'}`);
        console.log(`  Daily Summary: ${JSON.stringify(orgData.dailySummarySettings || 'None')}`);
        console.log(`  Has users: ${usersCount > 0}`);
        console.log(`  Has checklists: ${checklistsCount > 0}`);
        console.log(`  Has tasks: ${tasksCount > 0}`);
        console.log(`  Has locations: ${locationsCount > 0}`);
        
        // If it has daily summary settings with hour 15 and minute 20 (3:20 PM)
        if (orgData.dailySummarySettings && orgData.dailySummarySettings.hour === 15 && orgData.dailySummarySettings.minute === 20) {
          console.log(`  🎯 THIS ORG HAS 3:20 PM TIME SETTING!`);
        }
        
        console.log('');
      }
    }
    
    // Also specifically look for orgs with 15:20 time setting
    console.log('\n=== Looking specifically for 3:20 PM time setting ===');
    let foundTargetTime = false;
    
    orgsQuery.docs.forEach(doc => {
      const data = doc.data();
      if (data.dailySummarySettings && data.dailySummarySettings.hour === 15 && data.dailySummarySettings.minute === 20) {
        console.log(`🎯 Found org with 3:20 PM setting: ${doc.id}`);
        console.log(`   Name: ${data.name || 'No name'}`);
        foundTargetTime = true;
      }
    });
    
    if (!foundTargetTime) {
      console.log('No organizations found with 15:20 (3:20 PM) time setting');
      
      // Show all daily summary time settings
      console.log('\n=== All daily summary time settings ===');
      orgsQuery.docs.forEach(doc => {
        const data = doc.data();
        if (data.dailySummarySettings && data.dailySummarySettings.enabled) {
          const hour = data.dailySummarySettings.hour;
          const minute = data.dailySummarySettings.minute;
          const timeStr = `${hour}:${minute.toString().padStart(2, '0')}`;
          console.log(`${doc.id}: ${timeStr} (${hour >= 12 ? (hour === 12 ? '12' : hour - 12) : hour === 0 ? '12' : hour}:${minute.toString().padStart(2, '0')} ${hour >= 12 ? 'PM' : 'AM'})`);
        }
      });
    }
    
  } catch (error) {
    console.error('Error finding orgs with data:', error);
  }
}

findOrgsWithData().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});