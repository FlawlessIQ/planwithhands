const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
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
    console.log(`🔧 ${dryRun ? 'DRY RUN' : 'LIVE RUN'} - Deduplicating carry-forward tasks...\n`);
    
    const today = new Date();
    const todayStr = formatDate(today);
    
    let totalDuplicatesRemoved = 0;
    let checklistsProcessed = 0;
    
    // Query all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.name || orgData.organizationName || orgId;
      
      console.log(`\n🏢 ${orgName}`);
      console.log('='.repeat(60));
      
      // Get all locations
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationName = locationDoc.data().locationName || locationId;
        
        // Check today's checklists
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
          
          // Get tasks from subcollection
          const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
          
          if (tasksSnapshot.docs.length === 0) continue;
          
          checklistsProcessed++;
          
          // Group tasks by unique identifier
          const taskGroups = {};
          
          for (const taskDoc of tasksSnapshot.docs) {
            const taskData = taskDoc.data();
            const taskName = taskData.taskName || taskData.name || 'Unknown';
            const isCarryForward = taskData.isCarryForward === true;
            const completed = taskData.completed === true;
            const originalTaskId = taskData.originalTaskId || '';
            const taskId = taskData.taskId || taskDoc.id;
            
            // Only process carry-forward tasks
            if (!isCarryForward) continue;
            
            // Create a unique key for this task (by name + originalTaskId)
            // We keep the name as primary key since that's what users see
            const uniqueKey = `${taskName}|${originalTaskId}`;
            
            if (!taskGroups[uniqueKey]) {
              taskGroups[uniqueKey] = [];
            }
            
            taskGroups[uniqueKey].push({
              docRef: taskDoc.ref,
              docId: taskDoc.id,
              taskData: taskData,
              taskName: taskName,
              completed: completed,
              createdAt: taskData.createdAt,
            });
          }
          
          // Find and remove duplicates
          let duplicatesInChecklist = 0;
          
          for (const [uniqueKey, tasks] of Object.entries(taskGroups)) {
            if (tasks.length > 1) {
              // We have duplicates!
              const [taskName] = uniqueKey.split('|');
              
              // Sort by: 1) completed status (keep completed), 2) createdAt (keep oldest)
              tasks.sort((a, b) => {
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
              
              // Keep the first one (best candidate), delete the rest
              const toKeep = tasks[0];
              const toDelete = tasks.slice(1);
              
              console.log(`   🔴 "${taskName}": ${tasks.length} copies (${toDelete.length} to remove)`);
              console.log(`      Keeping: ${toKeep.docId} (completed: ${toKeep.completed})`);
              
              for (const task of toDelete) {
                console.log(`      ${dryRun ? 'Would delete' : 'Deleting'}: ${task.docId} (completed: ${task.completed})`);
                
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
          
          if (duplicatesInChecklist > 0) {
            console.log(`   ✅ ${checklistName}: ${duplicatesInChecklist} duplicate(s) ${dryRun ? 'found' : 'removed'}`);
          }
        }
      }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log(`📊 Summary:`);
    console.log(`   Checklists processed: ${checklistsProcessed}`);
    console.log(`   Duplicate tasks ${dryRun ? 'found' : 'removed'}: ${totalDuplicatesRemoved}`);
    
    if (dryRun) {
      console.log('\n⚠️  This was a DRY RUN - no tasks were deleted.');
      console.log('   Run with --live to actually remove duplicates.');
    } else {
      console.log('\n✅ Deduplication complete!');
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
  console.log('   Starting in 3 seconds... Press Ctrl+C to cancel.\n');
  
  setTimeout(() => {
    deduplicateCarryForwardTasks(false).then(() => {
      console.log('\n✅ Done!');
      process.exit(0);
    }).catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
  }, 3000);
} else {
  deduplicateCarryForwardTasks(true).then(() => {
    console.log('\n✅ Done!');
    process.exit(0);
  }).catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}
