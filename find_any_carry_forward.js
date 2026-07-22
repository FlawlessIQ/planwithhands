const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function findAnyCarryForwardTasks() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    console.log('🔍 Searching for ANY carry-forward tasks in the organization...\n');
    console.log(`Organization: ${orgId}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Query for ANY carry-forward tasks in this org
    const tasksQuery = await db.collectionGroup('tasks')
      .where('organizationId', '==', orgId)
      .where('isCarryForward', '==', true)
      .limit(200)
      .get();
    
    console.log(`Found ${tasksQuery.docs.length} carry-forward tasks (total, any date)\n`);
    
    if (tasksQuery.docs.length > 0) {
      const byDateString = {};
      const byLocation = {};
      
      for (const doc of tasksQuery.docs) {
        const data = doc.data();
        const dateString = data.dateString || 'no-dateString';
        const locationId = data.locationId || 'no-locationId';
        
        if (!byDateString[dateString]) {
          byDateString[dateString] = [];
        }
        byDateString[dateString].push(doc.ref.path);
        
        if (!byLocation[locationId]) {
          byLocation[locationId] = 0;
        }
        byLocation[locationId]++;
      }
      
      console.log('By dateString field:');
      for (const [dateString, paths] of Object.entries(byDateString)) {
        console.log(`  ${dateString}: ${paths.length} tasks`);
        if (paths.length <= 3) {
          paths.forEach(p => console.log(`    - ${p}`));
        }
      }
      
      console.log('\nBy locationId:');
      // Get location names
      const locationNames = {};
      const locationsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations')
        .get();
      
      locationsSnapshot.docs.forEach(doc => {
        locationNames[doc.id] = doc.data().name || 'Unknown';
      });
      
      for (const [locationId, count] of Object.entries(byLocation)) {
        const name = locationNames[locationId] || 'Unknown';
        console.log(`  ${name} (${locationId}): ${count} tasks`);
      }
      
      console.log('\nSample tasks (first 5):');
      tasksQuery.docs.slice(0, 5).forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.taskName || data.title || 'Untitled'}`);
        console.log(`    Path: ${doc.ref.path}`);
        console.log(`    dateString: ${data.dateString || 'MISSING'}`);
        console.log(`    locationId: ${data.locationId || 'MISSING'}`);
        console.log(`    templateName: ${data.templateName || data.checklistName || 'MISSING'}`);
        console.log('');
      });
      
    } else {
      console.log('✅ No carry-forward tasks found anywhere in the organization.\n');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

findAnyCarryForwardTasks();
