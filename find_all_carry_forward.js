const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function findAllCarryForwardTasks() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const today = '2025-10-12';
    
    console.log('🔍 Finding ALL carry-forward tasks across all locations...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Today: ${today}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    let grandTotal = 0;
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationName = locationData.name || 'Unknown';
      const locationId = locationDoc.id;
      
      console.log(`\n📍 ${locationName} (${locationId})\n`);
      
      // Get today's checklists
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', today)
        .get();
      
      console.log(`  Checklists for today: ${checklistsSnapshot.docs.length}\n`);
      
      let locationTotal = 0;
      const byDate = {};
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'Unknown';
        
        // Get ALL carry-forward tasks
        const tasksSnapshot = await checklistDoc.ref
          .collection('tasks')
          .where('isCarryForward', '==', true)
          .get();
        
        if (tasksSnapshot.docs.length > 0) {
          console.log(`  📋 ${templateName}: ${tasksSnapshot.docs.length} carry-forward tasks`);
          
          // Group by original date
          for (const taskDoc of tasksSnapshot.docs) {
            const taskData = taskDoc.data();
            const originalDate = taskData.originalDate;
            
            let dateStr = 'unknown';
            if (typeof originalDate === 'string') {
              dateStr = originalDate;
            } else if (originalDate && originalDate._seconds) {
              const date = new Date(originalDate._seconds * 1000);
              dateStr = date.toISOString().split('T')[0];
            } else if (originalDate && originalDate.toDate) {
              dateStr = originalDate.toDate().toISOString().split('T')[0];
            }
            
            if (!byDate[dateStr]) {
              byDate[dateStr] = 0;
            }
            byDate[dateStr]++;
            locationTotal++;
          }
        }
      }
      
      if (locationTotal > 0) {
        console.log(`\n  Breakdown by original date:`);
        const sortedDates = Object.keys(byDate).sort();
        for (const date of sortedDates) {
          console.log(`    ${date}: ${byDate[date]} tasks`);
        }
        console.log(`\n  ⚠️  Total: ${locationTotal} carry-forward tasks\n`);
        grandTotal += locationTotal;
      } else {
        console.log(`  ✅ No carry-forward tasks\n`);
      }
      
      console.log(`${'='.repeat(80)}`);
    }
    
    console.log(`\n🎯 GRAND TOTAL: ${grandTotal} carry-forward tasks across all locations\n`);
    
    if (grandTotal > 0) {
      console.log('💡 These tasks need to be deleted from ALL original dates, not just yesterday.\n');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

findAllCarryForwardTasks();
