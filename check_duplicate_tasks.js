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

async function checkForDuplicateTasks() {
  try {
    console.log('🔍 Checking for duplicate tasks in subcollections...\n');
    
    const today = new Date();
    const todayStr = formatDate(today);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = formatDate(yesterday);
    
    console.log(`📅 Today: ${todayStr}`);
    console.log(`📅 Yesterday: ${yesterdayStr}\n`);
    
    // Query all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.name || orgData.organizationName || orgId;
      
      console.log(`\n🏢 Organization: ${orgName} (${orgId})`);
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
        
        console.log(`\n📍 Location: ${locationName}`);
        
        // Check today's checklists
        const todayChecklistsSnapshot = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', '==', todayStr)
          .get();
        
        console.log(`   Found ${todayChecklistsSnapshot.docs.length} checklists for today`);
        
        for (const checklistDoc of todayChecklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const checklistName = checklistData.templateName || checklistData.checklistName || 'Unknown';
          
          // Get tasks from subcollection
          const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
          
          // Check for duplicates by taskId
          const taskIds = {};
          const taskNames = {};
          let duplicateCount = 0;
          
          for (const taskDoc of tasksSnapshot.docs) {
            const taskData = taskDoc.data();
            const taskId = taskData.taskId || taskDoc.id;
            const taskName = taskData.taskName || taskData.name || 'Unknown';
            const isCarryForward = taskData.isCarryForward === true;
            
            // Track by taskId
            if (taskIds[taskId]) {
              taskIds[taskId].count++;
              duplicateCount++;
            } else {
              taskIds[taskId] = {
                count: 1,
                name: taskName,
                isCarryForward: isCarryForward,
                docId: taskDoc.id
              };
            }
            
            // Track by task name for carry-forward tasks
            if (isCarryForward) {
              const key = `${taskName}`;
              if (taskNames[key]) {
                taskNames[key].count++;
              } else {
                taskNames[key] = { count: 1, taskId: taskId };
              }
            }
          }
          
          if (duplicateCount > 0) {
            console.log(`   ⚠️  Checklist: ${checklistName} (${checklistDoc.id})`);
            console.log(`      Total tasks: ${tasksSnapshot.docs.length}`);
            console.log(`      Duplicate tasks found: ${duplicateCount}`);
            
            // Show which tasks are duplicated
            for (const [taskId, info] of Object.entries(taskIds)) {
              if (info.count > 1) {
                console.log(`         🔴 "${info.name}" (${taskId}): ${info.count} copies`);
              }
            }
          } else {
            console.log(`   ✅ Checklist: ${checklistName} - ${tasksSnapshot.docs.length} tasks (no duplicates)`);
          }
          
          // Check carry-forward task duplicates by name
          const cfDuplicates = Object.entries(taskNames).filter(([_, info]) => info.count > 1);
          if (cfDuplicates.length > 0) {
            console.log(`   ⚠️  Carry-forward duplicates by name:`);
            for (const [name, info] of cfDuplicates) {
              console.log(`         "${name}": ${info.count} copies`);
            }
          }
        }
      }
    }
    
    console.log('\n✅ Duplicate check complete!');
  } catch (error) {
    console.error('❌ Error checking for duplicates:', error);
  }
}

checkForDuplicateTasks().then(() => {
  console.log('\nDone!');
  process.exit(0);
}).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
