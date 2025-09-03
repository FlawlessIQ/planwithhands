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

async function testFlutterLogicEquivalent() {
  console.log(`🔍 Testing Flutter app equivalent logic`);
  
  const orgId = 'vnE0olvi1Tswjtdb19MI';
  const checklistId = 'vnE0olvi1Tswjtdb19MI_rGAc76DxU9TQhcJy21h0_u15N9xEmf0SdoAY7QPgq_vBhZgbusSlyJMX2el1xc_2025-09-03';
  const locationId = 'rGAc76DxU9TQhcJy21h0';
  
  try {
    // Get the daily checklist document
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
    const templateId = checklistData.templateId || checklistData.checklistTemplateId;
    console.log(`📋 Checklist: ${checklistData.checklistName || checklistData.templateName || 'Unnamed'}`);
    console.log(`📋 Template ID: ${templateId}`);
    console.log(`📋 Date: ${checklistData.date || checklistData.dateString}`);
    
    if (!templateId) {
      console.log('❌ No template ID found in checklist data');
      console.log('Checklist data:', JSON.stringify(checklistData, null, 2));
      return;
    }
    
    // Get all tasks in this checklist
    const tasksSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId)
      .collection('tasks')
      .get();
    
    console.log(`\n📝 Processing ${tasksSnapshot.docs.length} tasks with Flutter app logic:`);
    
    let photoRequiredTasks = [];
    
    for (const taskDoc of tasksSnapshot.docs) {
      const taskData = taskDoc.data();
      const taskName = taskData.taskName || taskData.name || 'Unnamed';
      const completed = taskData.completed === true;
      
      // Step 1: Check task's own photoRequired field (same as Flutter)
      let photoRequired = taskData.photoRequired === true;
      
      // Step 2: Apply fallback logic (same as Flutter)
      let finalPhotoRequired = photoRequired;
      
      if (!photoRequired) {
        const templateTaskId = taskData.templateTaskId;
        console.log(`\n   🔍 Task: "${taskName}" | completed: ${completed}`);
        console.log(`      Task photoRequired: ${taskData.photoRequired}`);
        console.log(`      Template Task ID: ${templateTaskId}`);
        
        if (templateTaskId && templateId) {
          try {
            // Get template task (exact same path as Flutter app)
            const templateTaskDoc = await db
              .collection('organizations').doc(orgId)
              .collection('checklist_templates').doc(templateId)
              .collection('tasks').doc(templateTaskId)
              .get();
            
            if (templateTaskDoc.exists) {
              const templateTaskData = templateTaskDoc.data();
              finalPhotoRequired = templateTaskData.photoRequired === true;
              console.log(`      Template photoRequired: ${templateTaskData.photoRequired} → final: ${finalPhotoRequired}`);
            } else {
              console.log(`      Template task not found`);
            }
          } catch (e) {
            console.log(`      Error getting template task: ${e.message}`);
          }
        }
      } else {
        console.log(`\n   ✅ Task: "${taskName}" | completed: ${completed} | direct photoRequired: true`);
      }
      
      // Step 3: Apply photo_required filter (same logic as Flutter)
      if (finalPhotoRequired) {
        photoRequiredTasks.push({
          name: taskName,
          completed: completed,
          finalPhotoRequired: finalPhotoRequired
        });
        console.log(`      📸 INCLUDED in photo_required filter`);
      } else {
        console.log(`      ⭕ FILTERED OUT (not photo required)`);
      }
    }
    
    console.log(`\n📊 RESULTS:`);
    console.log(`   Total tasks: ${tasksSnapshot.docs.length}`);
    console.log(`   Photo required tasks: ${photoRequiredTasks.length}`);
    
    if (photoRequiredTasks.length > 0) {
      console.log(`\n   📸 Photo required tasks that should appear in filter:`);
      photoRequiredTasks.forEach((task, i) => {
        console.log(`   ${i + 1}. "${task.name}" (completed: ${task.completed})`);
      });
      console.log(`\n✅ SUCCESS: The photo required filter should now work in the Flutter app!`);
    } else {
      console.log(`\n⚠️  No photo required tasks found`);
    }
    
  } catch (error) {
    console.error(`❌ Error testing logic:`, error);
  }
}

testFlutterLogicEquivalent()
  .then(() => {
    console.log(`\n🎉 Test completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Test failed:`, error);
    process.exit(1);
  });
