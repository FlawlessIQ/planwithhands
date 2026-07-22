const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./plan-with-hands-firebase-adminsdk-qyt1y-992db190d5.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://plan-with-hands.firebaseio.com"
});

const db = admin.firestore();
// CRITICAL: Use the correct database
const planWithHandsDb = db;

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function checkClosingCopyShift() {
  try {
    console.log('=== Investigating "(Chickies) CLOSING (Copy)" Shift ===\n');

    // Get all locations
    const locationsSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .get();

    let chickiesLocationId = null;
    for (const locDoc of locationsSnapshot.docs) {
      const locData = locDoc.data();
      if (locData.name === 'Chickies') {
        chickiesLocationId = locDoc.id;
        console.log(`Found Chickies location: ${chickiesLocationId}\n`);
        break;
      }
    }

    if (!chickiesLocationId) {
      console.log('Chickies location not found!');
      return;
    }

    // Get yesterday's date (October 11, 2025)
    const yesterday = new Date('2025-10-11');
    const yesterdayStr = yesterday.toISOString().split('T')[0];
    console.log(`Checking for checklists from: ${yesterdayStr}\n`);

    // Get all checklists from yesterday
    const checklistsSnapshot = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .where('date', '>=', admin.firestore.Timestamp.fromDate(new Date(yesterdayStr)))
      .where('date', '<', admin.firestore.Timestamp.fromDate(new Date('2025-10-12')))
      .get();

    console.log(`Found ${checklistsSnapshot.size} checklists from yesterday\n`);

    // Find the CLOSING (Copy) checklist
    let closingCopyChecklist = null;
    for (const checklistDoc of checklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      if (checklistData.checklistName && checklistData.checklistName.includes('CLOSING') && checklistData.checklistName.includes('Copy')) {
        closingCopyChecklist = { id: checklistDoc.id, ...checklistData };
        break;
      }
    }

    if (!closingCopyChecklist) {
      console.log('⚠️  No CLOSING (Copy) checklist found from yesterday');
      console.log('\nAll checklists from yesterday:');
      checklistsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.checklistName} (Shift ID: ${data.shiftId})`);
      });
      return;
    }

    console.log('📋 Found CLOSING (Copy) Checklist:');
    console.log(`   ID: ${closingCopyChecklist.id}`);
    console.log(`   Name: ${closingCopyChecklist.checklistName}`);
    console.log(`   Shift ID: ${closingCopyChecklist.shiftId}`);
    console.log(`   Total Items: ${closingCopyChecklist.totalItems}`);
    console.log(`   Completed: ${closingCopyChecklist.completedItems}`);
    console.log(`   Date: ${closingCopyChecklist.date.toDate()}\n`);

    // Now check if this shift ID exists in the shifts collection
    const shiftId = closingCopyChecklist.shiftId;
    console.log(`🔍 Checking if shift "${shiftId}" exists in database...\n`);

    const shiftDoc = await planWithHandsDb
      .collection('organizations')
      .doc(ORG_ID)
      .collection('shifts')
      .doc(shiftId)
      .get();

    if (!shiftDoc.exists) {
      console.log('❌ SHIFT DOES NOT EXIST - This is an "Unknown Shift" scenario!');
      console.log('   The shift document has been deleted but checklists still reference it.\n');
      
      // Count tasks in this checklist
      const tasksSnapshot = await planWithHandsDb
        .collection('organizations')
        .doc(ORG_ID)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .doc(closingCopyChecklist.id)
        .collection('tasks')
        .get();

      console.log(`📊 This checklist has ${tasksSnapshot.size} tasks in the subcollection`);
      console.log(`   (Metadata says: ${closingCopyChecklist.totalItems} total, ${closingCopyChecklist.completedItems} completed)\n`);

      // Show sample tasks
      console.log('Sample tasks:');
      tasksSnapshot.docs.slice(0, 5).forEach(taskDoc => {
        const task = taskDoc.data();
        console.log(`   - ${task.title} (Completed: ${task.isCompleted})`);
      });

    } else {
      const shiftData = shiftDoc.data();
      console.log('✅ SHIFT EXISTS in database');
      console.log(`   Name: ${shiftData.name}`);
      console.log(`   Days: ${shiftData.days ? shiftData.days.join(', ') : 'N/A'}`);
      console.log(`   Repeats Daily: ${shiftData.repeatsDaily}`);
      console.log(`   Active: ${shiftData.isActive}`);
      console.log('\n🤔 This is NOT an unknown shift - the shift document exists.');
      console.log('   The "(Copy)" suffix might indicate a duplicated shift or naming convention.');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

checkClosingCopyShift();
