const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkAllLocations() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    console.log('📍 Checking all locations in organization...\n');
    
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`Found ${locationsSnapshot.docs.length} locations:\n`);
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      console.log(`Location ID: ${locationDoc.id}`);
      console.log(`Name: ${locationData.name || 'Unknown'}`);
      console.log(`Address: ${locationData.address || 'N/A'}`);
      console.log(`Timezone: ${locationData.timezone || 'N/A'}\n`);
      
      // Check today's checklists for carry-forward tasks
      const today = '2025-10-12';
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationDoc.id)
        .collection('daily_checklists')
        .where('date', '==', today)
        .get();
      
      console.log(`  Checklists for today: ${checklistsSnapshot.docs.length}`);
      
      let totalCarryForward = 0;
      for (const checklistDoc of checklistsSnapshot.docs) {
        const tasksSnapshot = await checklistDoc.ref
          .collection('tasks')
          .where('isCarryForward', '==', true)
          .get();
        
        if (tasksSnapshot.docs.length > 0) {
          const checklistData = checklistDoc.data();
          console.log(`    - ${checklistData.templateName || 'Unknown'}: ${tasksSnapshot.docs.length} carry-forward tasks`);
          totalCarryForward += tasksSnapshot.docs.length;
        }
      }
      
      if (totalCarryForward > 0) {
        console.log(`  ⚠️  Total carry-forward tasks: ${totalCarryForward}`);
      } else {
        console.log(`  ✅ No carry-forward tasks`);
      }
      
      console.log(`\n${'='.repeat(80)}\n`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

checkAllLocations();
