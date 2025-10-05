const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');
const orgId = '3qjYzHagWmfbnMieJ1aj';
const locationId = 'sYhcOTkX1VkeoPjtPuwZ'; // from the path you provided
const checklistId = '3qjYzHagWmfbnMieJ1aj_sYhcOTkX1VkeoPjtPuwZ_aEwRngcnvjSh1glH19oz_2025-10-02';

async function analyzeSpecificChecklist() {
  console.log('🔍 ANALYZING SPECIFIC CHECKLIST');
  console.log(`Checklist ID: ${checklistId}`);
  console.log('=' .repeat(80));
  
  try {
    // 1. Get the specific checklist
    console.log('1️⃣ CHECKLIST DETAILS:');
    const checklistRef = db.collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId);
    
    const checklistSnap = await checklistRef.get();
    if (checklistSnap.exists) {
      const checklistData = checklistSnap.data();
      console.log('✅ Checklist exists:');
      console.log(JSON.stringify(checklistData, null, 2));
      
      // Analyze the checklist ID structure
      console.log('\n📋 CHECKLIST ID ANALYSIS:');
      const parts = checklistId.split('_');
      console.log(`Parts: ${JSON.stringify(parts)}`);
      if (parts.length >= 4) {
        console.log(`  Organization ID: ${parts[0]}`);
        console.log(`  Location ID: ${parts[1]}`);
        console.log(`  Shift/Template ID: ${parts[2]} ⚠️  THIS IS THE PROBLEM TEMPLATE ID`);
        console.log(`  Date: ${parts[3]}`);
      }
      
      // Check tasks in this checklist
      console.log('\n📝 TASKS IN CHECKLIST:');
      const tasksSnapshot = await checklistRef.collection('tasks').get();
      console.log(`Found ${tasksSnapshot.size} tasks:`);
      
      tasksSnapshot.docs.forEach(taskDoc => {
        const taskData = taskDoc.data();
        console.log(`  - ${taskDoc.id}:`);
        console.log(`    Name: ${taskData.taskName || taskData.name || 'No name'}`);
        console.log(`    Template ID: ${taskData.templateId || taskData.checklistTemplateId || 'None'}`);
        console.log(`    Completed: ${taskData.completed}`);
        console.log(`    Created By: ${taskData.createdBy}`);
        console.log(`    Is Carry Forward: ${taskData.isCarryForward}`);
      });
      
    } else {
      console.log('❌ Checklist does not exist');
    }
    
    // 2. Check all checklists for this location today
    console.log('\n2️⃣ ALL TODAY\'S CHECKLISTS FOR LOCATION:');
    const today = '2025-10-02';
    
    const allTodayChecklists = await db.collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', today)
      .get();
    
    console.log(`Found ${allTodayChecklists.size} checklists for today:`);
    allTodayChecklists.docs.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${doc.id}:`);
      console.log(`    Created by: ${data.createdBy}`);
      console.log(`    Created at: ${data.createdAt?.toDate()}`);
      console.log(`    Shift ID: ${data.shiftId}`);
      console.log(`    Template IDs: ${JSON.stringify(data.checklistTemplateIds || [])}`);
    });
    
    // 3. Check recent checklists to see the pattern
    console.log('\n3️⃣ RECENT CHECKLISTS (LAST 5 DAYS):');
    const fiveDaysAgo = new Date();
    fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);
    
    const recentChecklists = await db.collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(fiveDaysAgo))
      .orderBy('createdAt', 'desc')
      .get();
    
    console.log(`Found ${recentChecklists.size} recent checklists:`);
    recentChecklists.docs.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${doc.id}:`);
      console.log(`    Date: ${data.date}`);
      console.log(`    Created by: ${data.createdBy}`);
      console.log(`    Shift ID: ${data.shiftId}`);
      
      // Check if this follows the same pattern
      if (doc.id.includes('aEwRngcnvjSh1glH19oz')) {
        console.log(`    ⚠️  ALSO USES PROBLEM TEMPLATE ID`);
      }
    });
    
    // 4. CRITICAL: Check if there's a shift with ID matching the template ID
    console.log('\n4️⃣ SHIFT CHECK:');
    const problemShiftId = 'aEwRngcnvjSh1glH19oz';
    const shiftRef = db.collection('organizations').doc(orgId)
      .collection('shifts').doc(problemShiftId);
    const shiftSnap = await shiftRef.get();
    
    if (shiftSnap.exists) {
      console.log(`✅ Found shift with ID ${problemShiftId}:`);
      console.log(JSON.stringify(shiftSnap.data(), null, 2));
    } else {
      console.log(`❌ No shift found with ID ${problemShiftId}`);
    }
    
    console.log('\n💡 ANALYSIS SUMMARY:');
    console.log('The checklist ID structure suggests this was created by the daily generator');
    console.log('with format: orgId_locationId_shiftId_date');
    console.log(`The "template ID" ${parts[2]} is actually being used as a shift ID`);
    console.log('This indicates the daily generator is creating checklists for a shift that');
    console.log('either doesn\'t exist or has invalid template references.');
    
  } catch (error) {
    console.error('❌ Error analyzing checklist:', error);
  }
  
  process.exit(0);
}

analyzeSpecificChecklist();