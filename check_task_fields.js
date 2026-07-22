const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkTaskFields() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const today = '2025-10-12';
    
    console.log('🔍 Checking task fields using collectionGroup query (like the app does)...\n');
    console.log(`Organization: ${orgId}`);
    console.log(`Today: ${today}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Query the same way the app does
    const tasksQuery = await db.collectionGroup('tasks')
      .where('organizationId', '==', orgId)
      .where('dateString', '==', today)
      .where('isCarryForward', '==', true)
      .get();
    
    console.log(`Found ${tasksQuery.docs.length} carry-forward tasks with dateString=${today}\n`);
    
    if (tasksQuery.docs.length > 0) {
      // Group by location
      const byLocation = {};
      
      for (const doc of tasksQuery.docs) {
        const data = doc.data();
        const locationId = data.locationId || 'unknown';
        const templateName = data.templateName || data.checklistName || 'Unknown';
        const originalDate = data.originalDate;
        
        let originalDateStr = 'unknown';
        if (typeof originalDate === 'string') {
          originalDateStr = originalDate;
        } else if (originalDate && originalDate._seconds) {
          const date = new Date(originalDate._seconds * 1000);
          originalDateStr = date.toISOString().split('T')[0];
        } else if (originalDate && originalDate.toDate) {
          originalDateStr = originalDate.toDate().toISOString().split('T')[0];
        }
        
        if (!byLocation[locationId]) {
          byLocation[locationId] = {
            tasks: [],
            byChecklist: {},
            byOriginalDate: {},
          };
        }
        
        byLocation[locationId].tasks.push({
          path: doc.ref.path,
          taskName: data.taskName || data.title,
          templateName,
          originalDate: originalDateStr,
          dateString: data.dateString,
        });
        
        // Count by checklist
        if (!byLocation[locationId].byChecklist[templateName]) {
          byLocation[locationId].byChecklist[templateName] = 0;
        }
        byLocation[locationId].byChecklist[templateName]++;
        
        // Count by original date
        if (!byLocation[locationId].byOriginalDate[originalDateStr]) {
          byLocation[locationId].byOriginalDate[originalDateStr] = 0;
        }
        byLocation[locationId].byOriginalDate[originalDateStr]++;
      }
      
      // Get location names
      const locationNames = {};
      const locationsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations')
        .get();
      
      locationsSnapshot.docs.forEach(doc => {
        locationNames[doc.id] = doc.data().name || 'Unknown';
      });
      
      // Display results
      for (const [locationId, data] of Object.entries(byLocation)) {
        const locationName = locationNames[locationId] || 'Unknown';
        console.log(`📍 ${locationName} (${locationId})`);
        console.log(`   Total: ${data.tasks.length} tasks\n`);
        
        console.log(`   By checklist:`);
        for (const [name, count] of Object.entries(data.byChecklist)) {
          console.log(`     - ${name}: ${count} tasks`);
        }
        
        console.log(`\n   By original date:`);
        for (const [date, count] of Object.entries(data.byOriginalDate)) {
          console.log(`     - ${date}: ${count} tasks`);
        }
        
        console.log(`\n   Sample tasks (first 3):`);
        data.tasks.slice(0, 3).forEach(t => {
          console.log(`     - ${t.taskName} (from ${t.originalDate})`);
          console.log(`       Path: ${t.path}`);
        });
        
        console.log(`\n${'='.repeat(80)}\n`);
      }
    } else {
      console.log('✅ No carry-forward tasks found with this query.\n');
      console.log('This means the app should show 0 missed tasks.\n');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

checkTaskFields();
