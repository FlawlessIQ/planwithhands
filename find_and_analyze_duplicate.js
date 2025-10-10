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

async function findAndAnalyzeDuplicate() {
  try {
    const today = new Date();
    const todayStr = formatDate(today);
    
    console.log('🔍 Finding a checklist with carry-forward duplicates...\n');
    
    // Look at all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.name || orgData.organizationName || orgId;
      
      // Get locations
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationName = locationDoc.data().locationName || locationId;
        
        // Get today's checklists
        const checklistsSnapshot = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', '==', todayStr)
          .get();
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const checklistName = checklistData.templateName || 'Unknown';
          
          // Get tasks
          const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
          
          // Group by name
          const byName = {};
          let hasDuplicates = false;
          
          for (const taskDoc of tasksSnapshot.docs) {
            const taskData = taskDoc.data();
            const taskName = taskData.taskName || 'Unknown';
            
            byName[taskName] = (byName[taskName] || 0) + 1;
            
            if (byName[taskName] > 1) {
              hasDuplicates = true;
            }
          }
          
          if (hasDuplicates) {
            console.log('\n✅ FOUND ONE WITH DUPLICATES!');
            console.log(`🏢 Org: ${orgName} (${orgId})`);
            console.log(`📍 Location: ${locationName} (${locationId})`);
            console.log(`📋 Checklist: ${checklistName} (${checklistDoc.id})`);
            console.log(`   Total tasks: ${tasksSnapshot.docs.length}\n`);
            
            // Show duplicates
            for (const [name, count] of Object.entries(byName)) {
              if (count > 1) {
                console.log(`   "${name}": ${count} copies`);
              }
            }
            
            // Now analyze these duplicates in detail
            console.log('\n📊 DETAILED ANALYSIS:');
            console.log('='.repeat(80));
            
            for (const taskDoc of tasksSnapshot.docs) {
              const taskData = taskDoc.data();
              const taskName = taskData.taskName || 'Unknown';
              
              if (byName[taskName] > 1) {
                console.log(`\nTask: "${taskName}"`);
                console.log(`   Doc ID: ${taskDoc.id}`);
                console.log(`   Task ID: ${taskData.taskId}`);
                console.log(`   IsCarryForward: ${taskData.isCarryForward}`);
                console.log(`   Completed: ${taskData.completed}`);
                console.log(`   OriginalTaskId: ${taskData.originalTaskId || 'none'}`);
                console.log(`   OriginalChecklistId: ${taskData.originalChecklistId || 'none'}`);
              }
            }
            
            return; // Found one, stop
          }
        }
      }
    }
    
    console.log('❌ No duplicates found!');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

findAndAnalyzeDuplicate().then(() => {
  console.log('\nDone!');
  process.exit(0);
}).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
