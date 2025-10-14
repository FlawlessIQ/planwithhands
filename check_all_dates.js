const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkAllDates() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    console.log('🔍 Checking for carry-forward tasks across all dates...\n');
    console.log(`${'='.repeat(80)}\n`);
    
    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationName = locationData.name || 'Unknown';
      const locationId = locationDoc.id;
      
      console.log(`📍 ${locationName} (${locationId})\n`);
      
      // Get all checklists for this location (last 7 days)
      const dates = [];
      for (let i = 0; i < 7; i++) {
        const date = new Date('2025-10-12');
        date.setDate(date.getDate() - i);
        dates.push(date.toISOString().split('T')[0]);
      }
      
      for (const dateStr of dates) {
        const checklistsSnapshot = await db
          .collection('organizations').doc(orgId)
          .collection('locations').doc(locationId)
          .collection('daily_checklists')
          .where('date', '==', dateStr)
          .get();
        
        if (checklistsSnapshot.docs.length === 0) continue;
        
        let dateCarryForwardCount = 0;
        for (const checklistDoc of checklistsSnapshot.docs) {
          const tasksSnapshot = await checklistDoc.ref
            .collection('tasks')
            .where('isCarryForward', '==', true)
            .get();
          
          dateCarryForwardCount += tasksSnapshot.docs.length;
        }
        
        if (dateCarryForwardCount > 0) {
          console.log(`  ${dateStr}: ${dateCarryForwardCount} carry-forward tasks`);
        }
      }
      
      console.log('');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

checkAllDates();
