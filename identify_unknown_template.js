const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');
const orgId = '3qjYzHagWmfbnMieJ1aj';
const locationId = 'sYhcOTkX1VkeoPjtPuwZ'; // Lakeside BBQ

async function identifyUnknownTemplateIssue() {
  console.log('🔍 IDENTIFYING UNKNOWN TEMPLATE ISSUE');
  console.log(`Organization: ${orgId}`);
  console.log(`Location: ${locationId} (Lakeside BBQ)`);
  console.log('=' .repeat(80));
  
  try {
    // 1. Get today's checklists for this location
    console.log('1️⃣ ANALYZING TODAY\'S CHECKLISTS:');
    const today = '2025-10-02';
    
    const todayChecklists = await db.collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', today)
      .get();
    
    console.log(`Found ${todayChecklists.size} checklists for ${today}:`);
    
    const validTemplateIds = ['DHz50oOtwOYaH1mRhJlu', 'JR599ZROMJ93uPr0S4uj', 'C50oqsAGPshQ2Xxv4p2n'];
    const invalidChecklists = [];
    
    for (const checklistDoc of todayChecklists.docs) {
      const checklistData = checklistDoc.data();
      const templateIds = checklistData.checklistTemplateIds || [];
      
      console.log(`\n📋 Checklist: ${checklistDoc.id}`);
      console.log(`  Template IDs: ${JSON.stringify(templateIds)}`);
      console.log(`  Shift ID: ${checklistData.shiftId}`);
      console.log(`  Created by: ${checklistData.createdBy}`);
      console.log(`  Created at: ${checklistData.createdAt?.toDate()}`);
      
      // Check if any template IDs are invalid
      const invalidTemplateIds = templateIds.filter(tid => !validTemplateIds.includes(tid));
      if (invalidTemplateIds.length > 0) {
        console.log(`  ⚠️  INVALID TEMPLATE IDs: ${JSON.stringify(invalidTemplateIds)}`);
        invalidChecklists.push({
          id: checklistDoc.id,
          invalidTemplateIds,
          allTemplateIds: templateIds,
          shiftId: checklistData.shiftId
        });
      }
      
      // Check tasks in this checklist
      const tasksSnapshot = await checklistDoc.ref.collection('tasks').limit(5).get();
      console.log(`  Tasks: ${tasksSnapshot.size}`);
      
      tasksSnapshot.docs.forEach(taskDoc => {
        const taskData = taskDoc.data();
        const taskTemplateId = taskData.templateId || taskData.checklistTemplateId;
        if (taskTemplateId && !validTemplateIds.includes(taskTemplateId)) {
          console.log(`    ⚠️  Task with invalid template: ${taskDoc.id} -> ${taskTemplateId}`);
        }
      });
    }
    
    // 2. Check what templates actually exist
    console.log('\n2️⃣ CHECKING ACTUAL TEMPLATES:');
    for (const templateId of validTemplateIds) {
      const templateRef = db.collection('organizations').doc(orgId)
        .collection('checklist_templates').doc(templateId);
      const templateSnap = await templateRef.get();
      
      if (templateSnap.exists) {
        const templateData = templateSnap.data();
        console.log(`✅ ${templateId}: "${templateData.name}" (Active: ${templateData.isActive})`);
      } else {
        console.log(`❌ ${templateId}: DOES NOT EXIST`);
      }
    }
    
    // 3. Look for carry-forward issues
    console.log('\n3️⃣ CHECKING CARRY-FORWARD LOGIC:');
    const yesterday = '2025-10-01';
    
    const yesterdayChecklists = await db.collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', yesterday)
      .get();
    
    console.log(`Found ${yesterdayChecklists.size} checklists from ${yesterday}:`);
    
    for (const yDoc of yesterdayChecklists.docs) {
      const yData = yDoc.data();
      console.log(`\n📅 Yesterday's checklist: ${yDoc.id}`);
      console.log(`  Template IDs: ${JSON.stringify(yData.checklistTemplateIds || [])}`);
      
      // Check for carry-forward tasks
      const yTasksSnapshot = await yDoc.ref.collection('tasks').get();
      console.log(`  Tasks: ${yTasksSnapshot.size}`);
      
      let incompleteTasksCount = 0;
      yTasksSnapshot.docs.forEach(taskDoc => {
        const taskData = taskDoc.data();
        const isCompleted = taskData.completed || taskData.isComplete;
        if (!isCompleted) {
          incompleteTasksCount++;
          const taskTemplateId = taskData.templateId || taskData.checklistTemplateId;
          if (taskTemplateId && !validTemplateIds.includes(taskTemplateId)) {
            console.log(`    ⚠️  Incomplete task with invalid template: ${taskDoc.id} -> ${taskTemplateId}`);
          }
        }
      });
      
      console.log(`  Incomplete tasks: ${incompleteTasksCount}`);
    }
    
    // 4. Root cause analysis
    console.log('\n4️⃣ ROOT CAUSE ANALYSIS:');
    
    if (invalidChecklists.length > 0) {
      console.log(`❌ Found ${invalidChecklists.length} checklists with invalid template IDs:`);
      invalidChecklists.forEach(checklist => {
        console.log(`  - ${checklist.id}:`);
        console.log(`    Invalid templates: ${JSON.stringify(checklist.invalidTemplateIds)}`);
        console.log(`    Shift ID: ${checklist.shiftId}`);
      });
      
      console.log('\n💡 LIKELY CAUSES:');
      console.log('1. Carry-forward logic copying tasks from checklists with invalid template IDs');
      console.log('2. Template IDs that were valid before but templates were deleted');
      console.log('3. Bug in daily generator template validation');
      
      console.log('\n🛠️  IMMEDIATE SOLUTION:');
      console.log('1. Delete today\'s invalid checklists');
      console.log('2. Fix carry-forward logic to validate template IDs');
      console.log('3. Add stricter validation in daily generator');
      
    } else {
      console.log('✅ All checklists have valid template IDs');
      console.log('The "Unknown Template" might be caused by:');
      console.log('1. App-side template name resolution');
      console.log('2. Template exists but has no name');
      console.log('3. Cache issues in the app');
    }
    
    // 5. Generate cleanup script
    if (invalidChecklists.length > 0) {
      console.log('\n5️⃣ CLEANUP SCRIPT:');
      console.log('To delete invalid checklists, run:');
      
      for (const checklist of invalidChecklists) {
        console.log(`// Delete checklist: ${checklist.id}`);
        console.log(`await db.collection('organizations').doc('${orgId}')`);
        console.log(`  .collection('locations').doc('${locationId}')`);
        console.log(`  .collection('daily_checklists').doc('${checklist.id}').delete();`);
        console.log('');
      }
    }
    
  } catch (error) {
    console.error('❌ Error identifying unknown template issue:', error);
  }
  
  process.exit(0);
}

identifyUnknownTemplateIssue();