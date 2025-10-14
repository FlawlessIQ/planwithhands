const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
// IMPORTANT: Target the planwithhands database, NOT the default database
db.settings({ databaseId: 'planwithhands' });

/**
 * Delete all checklists associated with the unknown/deleted shift
 * Database: planwithhands (NOT default)
 */

async function deleteUnknownShiftChecklists() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // The Hamilton Inn
    const unknownShiftId = 'AaWOWV83vEU7dRns0jpo';
    
    console.log('🧹 Deleting checklists for unknown shift...\n');
    console.log(`⚠️  Database: planwithhands (NOT default)\n`);
    console.log(`Organization: ${orgId}`);
    console.log(`Location: The Hamilton Inn (${locationId})`);
    console.log(`Unknown Shift ID: ${unknownShiftId}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Verify database connection
    console.log('✅ Verifying database connection...\n');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.error('❌ Organization not found! Wrong database?');
      return;
    }
    console.log(`✅ Connected to correct database: planwithhands`);
    console.log(`   Organization: ${orgDoc.data().name || 'N/A'}\n`);
    
    console.log(`${'='.repeat(80)}\n`);
    
    // Find all checklists with this shift across all dates
    console.log('🔍 Finding all checklists with unknown shift...\n');
    
    const dates = [];
    for (let i = 0; i < 30; i++) {  // Check last 30 days
      const date = new Date('2025-10-12');
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split('T')[0]);
    }
    
    let totalChecklistsDeleted = 0;
    let totalTasksDeleted = 0;
    const deletionsByDate = {};
    
    for (const dateStr of dates) {
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .where('shiftId', '==', unknownShiftId)
        .get();
      
      if (checklistsSnapshot.docs.length > 0) {
        console.log(`📅 ${dateStr}: Found ${checklistsSnapshot.docs.length} checklists`);
        
        let dateTasksDeleted = 0;
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const templateName = checklistData.templateName || 'Unknown';
          const totalItems = checklistData.totalItems || 0;
          const completedItems = checklistData.completedItems || 0;
          
          console.log(`   - ${templateName} (${completedItems}/${totalItems} completed)`);
          
          // Delete all tasks in the checklist
          const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
          
          if (tasksSnapshot.docs.length > 0) {
            const batch = db.batch();
            tasksSnapshot.docs.forEach(taskDoc => {
              batch.delete(taskDoc.ref);
            });
            await batch.commit();
            
            dateTasksDeleted += tasksSnapshot.docs.length;
            console.log(`     ✅ Deleted ${tasksSnapshot.docs.length} tasks`);
          }
          
          // Delete the checklist document
          await checklistDoc.ref.delete();
          console.log(`     ✅ Deleted checklist`);
          
          totalChecklistsDeleted++;
        }
        
        totalTasksDeleted += dateTasksDeleted;
        deletionsByDate[dateStr] = {
          checklists: checklistsSnapshot.docs.length,
          tasks: dateTasksDeleted,
        };
        
        console.log('');
      }
    }
    
    console.log(`${'='.repeat(80)}\n`);
    
    if (totalChecklistsDeleted === 0) {
      console.log('✅ No checklists found with unknown shift.\n');
      return;
    }
    
    console.log(`✅ DELETION COMPLETE!\n`);
    console.log(`Summary:`);
    console.log(`  - Database: planwithhands`);
    console.log(`  - Deleted ${totalChecklistsDeleted} checklists`);
    console.log(`  - Deleted ${totalTasksDeleted} tasks`);
    console.log(`  - Affected dates: ${Object.keys(deletionsByDate).length}\n`);
    
    console.log(`Breakdown by date:`);
    for (const [date, stats] of Object.entries(deletionsByDate)) {
      console.log(`  ${date}: ${stats.checklists} checklists, ${stats.tasks} tasks`);
    }
    
    console.log(`\n💡 The "Unknown Shift" entries should no longer appear in the app.`);
    console.log(`   Refresh the app to see the changes.\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

deleteUnknownShiftChecklists();
