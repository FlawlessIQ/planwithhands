const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

function formatDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function deduplicateCarryForwardTasks(dryRun = true) {
  try {
    console.log(`🔧 ${dryRun ? 'DRY RUN' : 'LIVE RUN'} - Removing duplicate carry-forward tasks...\n`);
    
    const today = new Date();
    const todayStr = formatDate(today);
    
    let totalDuplicatesRemoved = 0;
    let checklistsProcessed = 0;
    
    const orgsSnapshot = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.name || orgData.organizationName || orgId;
      
      console.log(`\n🏢 ${orgName}`);
      console.log('='.repeat(60));
      
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationName = locationDoc.data().locationName || locationId;
        
        const todayChecklistsSnapshot = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', '==', todayStr)
          .get();
        
        if (todayChecklistsSnapshot.docs.length === 0) continue;
        
        console.log(`\n📍 ${locationName} (${todayChecklistsSnapshot.docs.length} checklists)`);
        
        for (const checklistDoc of todayChecklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const checklistName = checklistData.templateName || checklistData.checklistName || 'Unknown';
          
          const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
          
          if (tasksSnapshot.docs.length === 0) continue;
          
          checklistsProcessed++;
          
          // Group tasks by name
          const tasksByName = {};
          
          for (const taskDoc of tasksSnapshot.docs) {
            const taskData = taskDoc.data();
            const taskName = taskData.taskName || 'Unknown';
            
            if (!tasksByName[taskName]) {
              tasksByName[taskName] = {
                original: null,  // Today's template task
                carryForwards: []  // Yesterday's carry-forward tasks
              };
            }
            
            const isCarryForward = taskData.isCarryForward === true;
            
            if (isCarryForward) {
              tasksByName[taskName].carryForwards.push({
                docRef: taskDoc.ref,
                docId: taskDoc.id,
                taskData: taskData,
                completed: taskData.completed === true,
                createdAt: taskData.createdAt,
                originalTaskId: taskData.originalTaskId
              });
            } else {
              tasksByName[taskName].original = {
                docRef: taskDoc.ref,
                docId: taskDoc.id,
                taskData: taskData
              };
            }
          }
          
          // Find and remove duplicate carry-forwards (keep only the first one)
          let duplicatesInChecklist = 0;
          
          for (const [taskName, group] of Object.entries(tasksByName)) {
            // If there are multiple carry-forwards for the same task name, keep only one
            if (group.carryForwards.length > 1) {
              // Sort by: 1) completed status (keep completed), 2) createdAt (keep oldest)
              group.carryForwards.sort((a, b) => {
                if (a.completed !== b.completed) {
                  return a.completed ? -1 : 1; // Keep completed first
                }
                if (a.createdAt && b.createdAt) {
                  const aTime = a.createdAt.toMillis ? a.createdAt.toMillis() : 0;
                  const bTime = b.createdAt.toMillis ? b.createdAt.toMillis() : 0;
                  return aTime - bTime; // Keep oldest
                }
                return 0;
              });
              
              const toKeep = group.carryForwards[0];
              const toDelete = group.carryForwards.slice(1);
              
              console.log(`   🔴 "${taskName}": ${group.carryForwards.length} carry-forward copies (removing ${toDelete.length})`);
              console.log(`      Keeping: ${toKeep.docId}`);
              
              for (const task of toDelete) {
                console.log(`      ${dryRun ? 'Would delete' : 'Deleting'}: ${task.docId}`);
                
                if (!dryRun) {
                  try {
                    await task.docRef.delete();
                    duplicatesInChecklist++;
                    totalDuplicatesRemoved++;
                  } catch (error) {
                    console.error(`      ❌ Error deleting ${task.docId}:`, error.message);
                  }
                }
              }
            }
          }
          
          if (duplicatesInChecklist > 0 || (dryRun && Object.values(tasksByName).some(g => g.carryForwards.length > 1))) {
            const count = Object.values(tasksByName).filter(g => g.carryForwards.length > 1).length;
            console.log(`   ✅ ${checklistName}: ${count} task(s) had duplicate carry-forwards`);
          }
        }
      }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log(`📊 Summary:`);
    console.log(`   Checklists processed: ${checklistsProcessed}`);
    console.log(`   Duplicate carry-forwards ${dryRun ? 'found' : 'removed'}: ${totalDuplicatesRemoved}`);
    
    if (dryRun) {
      console.log('\n⚠️  This was a DRY RUN - no tasks were deleted.');
      console.log('   Run with --live to actually remove duplicates.');
    } else {
      console.log('\n✅ Deduplication complete!');
      console.log('   Dashboards should now show correct counts.');
    }
    
  } catch (error) {
    console.error('❌ Error during deduplication:', error);
    throw error;
  }
}

// Check command line arguments
const args = process.argv.slice(2);
const isLiveRun = args.includes('--live');

if (isLiveRun) {
  console.log('⚠️  WARNING: This is a LIVE RUN - duplicates will be DELETED!');
  console.log('   Starting in 5 seconds... Press Ctrl+C to cancel.\n');
  
  setTimeout(() => {
    deduplicateCarryForwardTasks(false).then(() => {
      console.log('\n✅ Done!');
      process.exit(0);
    }).catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
  }, 5000);
} else {
  deduplicateCarryForwardTasks(true).then(() => {
    console.log('\n✅ Done!');
    process.exit(0);
  }).catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}
