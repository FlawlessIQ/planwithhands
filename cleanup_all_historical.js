const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

/**
 * Clean up ALL carry-forward tasks from all historical dates
 * 
 * The duplicate task issue has been ongoing for multiple days, so we need to:
 * 1. Delete all carry-forward tasks from all past checklists
 * 2. Update checklist metrics
 */

async function cleanupAllHistoricalCarryForward() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const today = '2025-10-12';
    
    console.log('🧹 Cleaning up ALL historical carry-forward duplicates...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Today: ${today}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Get all dates from past 30 days
    const dates = [];
    for (let i = 1; i < 30; i++) {  // Start from 1 to exclude today
      const date = new Date('2025-10-12');
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split('T')[0]);
    }
    
    console.log(`Will check ${dates.length} historical dates...\n`);
    
    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    let grandTotal = 0;
    const locationSummaries = [];
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationName = locationData.name || 'Unknown';
      const locationId = locationDoc.id;
      
      console.log(`\n📍 ${locationName} (${locationId})\n`);
      
      let locationTotal = 0;
      const datesSummary = {};
      
      for (const dateStr of dates) {
        const checklistsSnapshot = await db
          .collection('organizations').doc(orgId)
          .collection('locations').doc(locationId)
          .collection('daily_checklists')
          .where('date', '==', dateStr)
          .get();
        
        if (checklistsSnapshot.docs.length === 0) continue;
        
        let dateDeletedCount = 0;
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const templateName = checklistData.templateName || 'Unknown';
          
          // Get all tasks
          const allTasksSnapshot = await checklistDoc.ref.collection('tasks').get();
          
          // Find carry-forward tasks (these are duplicates)
          const carryForwardTasks = allTasksSnapshot.docs.filter(d => 
            d.data().isCarryForward === true
          );
          
          if (carryForwardTasks.length > 0) {
            // Delete them
            const batch = db.batch();
            carryForwardTasks.forEach(taskDoc => {
              batch.delete(taskDoc.ref);
            });
            
            await batch.commit();
            dateDeletedCount += carryForwardTasks.length;
            
            // Update checklist metrics
            const remainingTasks = allTasksSnapshot.docs.length - carryForwardTasks.length;
            const completedTasks = allTasksSnapshot.docs.filter(d => 
              d.data().isCarryForward !== true && d.data().completed === true
            ).length;
            
            await checklistDoc.ref.update({
              totalItems: remainingTasks,
              completedItems: completedTasks,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
        
        if (dateDeletedCount > 0) {
          datesSummary[dateStr] = dateDeletedCount;
          locationTotal += dateDeletedCount;
        }
      }
      
      if (locationTotal > 0) {
        console.log(`  Cleaned dates:`);
        for (const [date, count] of Object.entries(datesSummary)) {
          console.log(`    ${date}: deleted ${count} tasks`);
        }
        console.log(`  \n  ✅ Total: ${locationTotal} tasks deleted\n`);
        
        locationSummaries.push({
          name: locationName,
          count: locationTotal,
        });
        grandTotal += locationTotal;
      } else {
        console.log(`  ✅ No carry-forward tasks found\n`);
      }
      
      console.log(`${'='.repeat(80)}`);
    }
    
    console.log(`\n✅ CLEANUP COMPLETE!\n`);
    console.log(`Summary by location:`);
    locationSummaries.forEach(s => {
      console.log(`  ${s.name}: ${s.count} tasks deleted`);
    });
    console.log(`\n🎯 Grand Total: ${grandTotal} duplicate carry-forward tasks removed\n`);
    console.log(`💡 All historical duplicate carry-forward tasks have been cleaned.`);
    console.log(`   Refresh the app to see the changes.\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

cleanupAllHistoricalCarryForward();
