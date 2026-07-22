const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function verifyDatabaseAndShifts() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // The Hamilton Inn
    
    console.log('🔍 Verifying database connection and shifts data...\n');
    console.log(`Database: planwithhands`);
    console.log(`Organization: ${orgId}`);
    console.log(`Location: ${locationId}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Check organization exists
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    console.log(`Organization document exists: ${orgDoc.exists}`);
    if (orgDoc.exists) {
      console.log(`Organization name: ${orgDoc.data().name || 'N/A'}\n`);
    }
    
    // Check location exists
    const locationDoc = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .get();
    console.log(`Location document exists: ${locationDoc.exists}`);
    if (locationDoc.exists) {
      console.log(`Location name: ${locationDoc.data().name || 'N/A'}\n`);
    }
    
    console.log(`${'='.repeat(80)}\n`);
    
    // Check shifts collection
    console.log('📅 Checking shifts collection:\n');
    const shiftsPath = `organizations/${orgId}/locations/${locationId}/shifts`;
    console.log(`Path: ${shiftsPath}\n`);
    
    const shiftsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('shifts')
      .get();
    
    console.log(`Shifts found: ${shiftsSnapshot.docs.length}\n`);
    
    if (shiftsSnapshot.docs.length > 0) {
      console.log('Shift details:\n');
      shiftsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  📅 ${data.name || 'Unnamed'}`);
        console.log(`     ID: ${doc.id}`);
        console.log(`     Days of week: ${data.daysOfWeek || 'N/A'}`);
        console.log(`     Time: ${data.startTime || 'N/A'} - ${data.endTime || 'N/A'}`);
        console.log(`     Active: ${data.isActive !== false}`);
        console.log('');
      });
    } else {
      console.log('⚠️  No shifts found in this collection!\n');
      console.log('Let me check alternative locations...\n');
      
      // Check if shifts might be at organization level
      const orgLevelShifts = await db
        .collection('organizations').doc(orgId)
        .collection('shifts')
        .get();
      
      console.log(`Shifts at organization level: ${orgLevelShifts.docs.length}\n`);
      
      if (orgLevelShifts.docs.length > 0) {
        console.log('Found shifts at organization level:\n');
        orgLevelShifts.docs.forEach(doc => {
          const data = doc.data();
          console.log(`  📅 ${data.name || 'Unnamed'} (${doc.id})`);
          console.log(`     Days: ${data.daysOfWeek || 'N/A'}`);
          console.log('');
        });
      }
    }
    
    console.log(`${'='.repeat(80)}\n`);
    
    // Check a sample checklist to see what shift data it contains
    console.log('📋 Checking sample checklist data:\n');
    const checklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', '2025-10-11')
      .limit(1)
      .get();
    
    if (!checklistsSnapshot.empty) {
      const sampleChecklist = checklistsSnapshot.docs[0];
      const data = sampleChecklist.data();
      console.log(`Sample checklist: ${data.templateName || 'Unknown'}`);
      console.log(`Checklist data fields:`);
      console.log(JSON.stringify(data, null, 2));
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

verifyDatabaseAndShifts();
