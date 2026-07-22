const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkShiftDetails() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    console.log('🔍 Checking shift details at organization level...\n');
    
    // Get the shift IDs we saw in the checklists
    const shiftIds = [
      'AaWOWV83vEU7dRns0jpo', // Open (Brunch/Weekday)
      'zCfZ5UigVjZ7KcqaWwWq', // Open (Weekday)
      'BFhX0nw8847CFLxKpxjK', // Camp - Open
      'Fy10vDXLBQqb0xOMrWFt', // Closing
      'PaIkD4hgOLmWyiGMJAPC', // Pre Dinner
    ];
    
    for (const shiftId of shiftIds) {
      const shiftDoc = await db
        .collection('organizations').doc(orgId)
        .collection('shifts').doc(shiftId)
        .get();
      
      if (shiftDoc.exists) {
        const data = shiftDoc.data();
        console.log(`📅 Shift: ${data.name || 'Unnamed'} (${shiftId})`);
        console.log(`   Full data:`);
        console.log(JSON.stringify(data, null, 2));
        console.log('\n' + '='.repeat(80) + '\n');
      } else {
        console.log(`⚠️  Shift ${shiftId} not found\n`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

checkShiftDetails();
