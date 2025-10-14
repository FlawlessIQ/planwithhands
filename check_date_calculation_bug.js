const admin = require('firebase-admin');
const {DateTime} = require('luxon');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

const HAMILTON_ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function checkDateCalculationBug() {
  console.log('\n=== CHECKING DATE CALCULATION BUG ===\n');
  
  // Simulate what happens at 8:00 AM UTC on Oct 12
  const utcNow = new Date('2025-10-12T08:00:00Z');
  console.log('Current UTC time (simulated):', utcNow.toISOString());
  console.log('UTC date:', utcNow.toISOString().split('T')[0]);
  
  // Get org settings
  const orgDoc = await db.collection('organizations').doc(HAMILTON_ORG_ID).get();
  const orgData = orgDoc.data();
  const timezone = orgData.timezone || 'America/New_York';
  
  console.log('\nOrganization timezone:', timezone);
  
  // Convert to org timezone
  const orgTime = DateTime.fromJSDate(utcNow).setZone(timezone);
  console.log('Organization local time:', orgTime.toISO());
  console.log('Organization local date:', orgTime.toFormat('yyyy-MM-dd'));
  
  // The summary at 4 AM should be for YESTERDAY
  const yesterdayInOrgTZ = orgTime.minus({ days: 1 });
  console.log('\nYesterday in org timezone:', yesterdayInOrgTZ.toFormat('yyyy-MM-dd'));
  
  // What the current code is doing (WRONG):
  const wrongDate = utcNow.toISOString().split('T')[0];
  console.log('\nWhat current code queries:', wrongDate, '(WRONG - this is UTC today)');
  
  // What it SHOULD be querying:
  const correctDate = yesterdayInOrgTZ.toFormat('yyyy-MM-dd');
  console.log('What it SHOULD query:', correctDate, '(Correct - yesterday in org TZ)');
  
  // Count checklists for each date
  console.log('\n=== CHECKING ACTUAL DATA ===\n');
  
  const locationsSnapshot = await db
    .collection('organizations')
    .doc(HAMILTON_ORG_ID)
    .collection('locations')
    .get();
  
  let wrongDateCount = 0;
  let correctDateCount = 0;
  
  for (const locationDoc of locationsSnapshot.docs) {
    const locationName = locationDoc.data().locationName;
    
    // Query with wrong date (UTC today)
    const wrongSnapshot = await db
      .collection('organizations')
      .doc(HAMILTON_ORG_ID)
      .collection('locations')
      .doc(locationDoc.id)
      .collection('daily_checklists')
      .where('date', '==', wrongDate)
      .get();
    
    // Query with correct date (yesterday in org TZ)
    const correctSnapshot = await db
      .collection('organizations')
      .doc(HAMILTON_ORG_ID)
      .collection('locations')
      .doc(locationDoc.id)
      .collection('daily_checklists')
      .where('date', '==', correctDate)
      .get();
    
    console.log(`Location: ${locationName}`);
    console.log(`  Checklists on ${wrongDate}: ${wrongSnapshot.size}`);
    console.log(`  Checklists on ${correctDate}: ${correctSnapshot.size}`);
    
    wrongDateCount += wrongSnapshot.size;
    correctDateCount += correctSnapshot.size;
    
    // Count tasks for correct date
    let taskCount = 0;
    for (const checklistDoc of correctSnapshot.docs) {
      const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
      taskCount += tasksSnapshot.size;
    }
    console.log(`  Total tasks on ${correctDate}: ${taskCount}\n`);
  }
  
  console.log('=== SUMMARY ===');
  console.log(`Total checklists on ${wrongDate} (wrong): ${wrongDateCount}`);
  console.log(`Total checklists on ${correctDate} (correct): ${correctDateCount}`);
  console.log('\nCONCLUSION:');
  if (wrongDateCount === 0 && correctDateCount > 0) {
    console.log('✗ BUG CONFIRMED! Function is querying the wrong date.');
    console.log('  It queries UTC today but should query yesterday in org timezone.');
    console.log('  This results in 0 tasks found, explaining the "0 tasks complete" issue.');
  } else {
    console.log('? Results unclear - need more investigation');
  }
}

checkDateCalculationBug()
  .then(() => {
    console.log('\nCheck complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('Error:', error);
    process.exit(1);
  });
