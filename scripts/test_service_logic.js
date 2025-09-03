#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();
// Connect to the planwithhands database
db.settings({
  databaseId: 'planwithhands'
});

async function testServiceLogic() {
  console.log(`🔍 Testing DailyChecklistService equivalent logic`);
  
  const orgId = 'vnE0olvi1Tswjtdb19MI';
  const locationId = 'rGAc76DxU9TQhcJy21h0';
  const checklistId = 'vnE0olvi1Tswjtdb19MI_rGAc76DxU9TQhcJy21h0_u15N9xEmf0SdoAY7QPgq_vBhZgbusSlyJMX2el1xc_2025-09-03';
  
  try {
    // Step 1: Get the parent checklist to get the template ID
    console.log(`\n📋 Getting checklist data:`);
    const checklistDoc = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId)
      .get();
    
    if (!checklistDoc.exists) {
      console.log('❌ Checklist not found');
      return;
    }
    
    const checklistData = checklistDoc.data();
    const templateId = checklistData.checklistTemplateId || checklistData.templateId;
    console.log(`   Template ID: ${templateId}`);
    
    // Step 2: Get template tasks for fallback
    let templateTaskMap = null;
    if (templateId) {
      console.log(`\n📚 Loading template tasks for fallback:`);
      try {
        const templateTasksSnapshot = await db
          .collection('organizations').doc(orgId)
          .collection('checklist_templates').doc(templateId)
          .collection('tasks').get();
        
        templateTaskMap = {};
        templateTasksSnapshot.docs.forEach(doc => {
          templateTaskMap[doc.id] = doc.data();
        });
        
        console.log(`   Loaded ${Object.keys(templateTaskMap).length} template tasks`);
        
        // Show template task details
        Object.entries(templateTaskMap).forEach(([id, data]) => {
          console.log(`   - ${data.name}: photoRequired = ${data.photoRequired} (ID: ${id})`);
        });
      } catch (e) {
        console.log(`   ❌ Error loading template tasks: ${e.message}`);
      }
    }
    
    // Step 3: Get tasks from subcollection
    console.log(`\n📝 Processing tasks with service logic:`);
    const tasksSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId)
      .collection('tasks').get();
    
    console.log(`   Found ${tasksSnapshot.docs.length} tasks`);
    
    let photoRequiredTasks = [];
    
    for (const taskDoc of tasksSnapshot.docs) {
      const taskData = taskDoc.data();
      const taskName = taskData.taskName || taskData.name || 'Unnamed';
      
      // Apply the same logic as DailyChecklistService
      let photoRequiredValue = false;
      
      console.log(`\n   🔍 Task: "${taskName}"`);
      console.log(`      Raw photoRequired: ${taskData.photoRequired}`);
      console.log(`      Has photoRequired field: ${taskData.hasOwnProperty('photoRequired')}`);
      
      if (taskData.hasOwnProperty('photoRequired')) {
        photoRequiredValue = taskData.photoRequired === true;
        console.log(`      Using task photoRequired: ${photoRequiredValue}`);
      } else {
        const templateTaskId = taskData.templateTaskId;
        console.log(`      Template task ID: ${templateTaskId}`);
        
        if (templateTaskId && templateTaskMap && templateTaskMap[templateTaskId]) {
          photoRequiredValue = templateTaskMap[templateTaskId].photoRequired === true;
          console.log(`      Using template photoRequired: ${photoRequiredValue} (from template)`);
        } else {
          photoRequiredValue = false;
          console.log(`      No template fallback available, using false`);
        }
      }
      
      console.log(`      📸 FINAL photoRequired: ${photoRequiredValue}`);
      
      if (photoRequiredValue) {
        photoRequiredTasks.push({
          name: taskName,
          completed: taskData.completed || false
        });
      }
    }
    
    console.log(`\n📊 RESULTS:`);
    console.log(`   Total tasks: ${tasksSnapshot.docs.length}`);
    console.log(`   Photo required tasks: ${photoRequiredTasks.length}`);
    
    if (photoRequiredTasks.length > 0) {
      console.log(`\n   📸 Photo required tasks:`);
      photoRequiredTasks.forEach((task, i) => {
        console.log(`   ${i + 1}. "${task.name}" (completed: ${task.completed})`);
      });
      console.log(`\n✅ SUCCESS: The DailyChecklistService logic should work correctly!`);
    } else {
      console.log(`\n⚠️  No photo required tasks found - tasks have photoRequired field set to false`);
      console.log(`     The service will use the existing field value rather than template fallback`);
    }
    
  } catch (error) {
    console.error(`❌ Error testing service logic:`, error);
  }
}

testServiceLogic()
  .then(() => {
    console.log(`\n🎉 Test completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Test failed:`, error);
    process.exit(1);
  });
