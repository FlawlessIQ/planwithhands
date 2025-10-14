const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();

async function findRecentChecklists() {
  try {
    console.log('🔍 Searching for organizations with checklists from the last 7 days...\n');
    
    const today = new Date();
    const sevenDaysAgo = new Date(today);
    sevenDaysAgo.setDate(today.getDate() - 7);
    
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`Found ${orgsSnapshot.docs.length} organizations\n`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgId = orgDoc.id;
      const orgName = orgData.name || 'Unnamed';
      
      // Get locations for this org
      const locationsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations')
        .limit(10)
        .get();
      
      if (locationsSnapshot.docs.length === 0) continue;
      
      // Check for recent checklists
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationData = locationDoc.data();
        const locationName = locationData.name || locationData.locationName || 'Unnamed Location';
        
        // Get recent checklists
        const checklistsSnapshot = await db
          .collection('organizations').doc(orgId)
          .collection('locations').doc(locationId)
          .collection('daily_checklists')
          .where('createdAt', '>=', sevenDaysAgo)
          .limit(5)
          .get();
        
        if (checklistsSnapshot.docs.length > 0) {
          console.log(`\n${'='.repeat(80)}`);
          console.log(`🏢 Organization: ${orgName}`);
          console.log(`   ID: ${orgId}`);
          console.log(`📍 Location: ${locationName}`);
          console.log(`   ID: ${locationId}`);
          console.log(`📋 Recent checklists: ${checklistsSnapshot.docs.length}`);
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            const date = checklistData.date;
            const templateName = checklistData.templateName || 'Unknown Template';
            
            // Get tasks count
            const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
            const totalTasks = tasksSnapshot.docs.length;
            const carryForwardTasks = tasksSnapshot.docs.filter(d => d.data().isCarryForward === true).length;
            const normalTasks = totalTasks - carryForwardTasks;
            
            console.log(`   • ${date} - ${templateName}`);
            console.log(`     Tasks: ${totalTasks} (${normalTasks} normal, ${carryForwardTasks} carry-forward)`);
            
            if (normalTasks === 0 && totalTasks > 0) {
              console.log(`     ⚠️  ALL TASKS ARE CARRY-FORWARD - THIS IS THE ISSUE!`);
            }
          }
        }
      }
    }
    
    console.log(`\n${'='.repeat(80)}`);
    console.log(`\n💡 Look for checklists where "ALL TASKS ARE CARRY-FORWARD"`);
    console.log(`   Those are the ones that need to be fixed.`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

findRecentChecklists();
