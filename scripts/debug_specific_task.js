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

async function debugSpecificTask() {
  console.log(`🔍 Debugging specific "check fridge temps" task`);
  
  const orgId = 'vnE0olvi1Tswjtdb19MI';
  const templateId = 'vBhZgbusSlyJMX2el1xc';
  const templateTaskId = '8684736526bf4e76';
  
  try {
    // 1. Check the template task (at organization level, not location level)
    console.log(`\n📋 Checking template task at organization level:`);
    const templateTaskRef = db
      .collection('organizations').doc(orgId)
      .collection('checklist_templates').doc(templateId)
      .collection('tasks').doc(templateTaskId);
    
    const templateTaskSnap = await templateTaskRef.get();
    if (templateTaskSnap.exists) {
      const templateTaskData = templateTaskSnap.data();
      console.log(`   ✅ Template task found:`);
      console.log(`   Name: ${templateTaskData.name || templateTaskData.taskName}`);
      console.log(`   PhotoRequired: ${templateTaskData.photoRequired}`);
      console.log(`   ID: ${templateTaskData.id || templateTaskId}`);
    } else {
      console.log(`   ❌ Template task not found at organization level`);
    }
    
    // 2. Find a specific daily checklist with the fridge task
    console.log(`\n📅 Checking specific daily checklist with fridge task:`);
    const checklistId = 'vnE0olvi1Tswjtdb19MI_rGAc76DxU9TQhcJy21h0_u15N9xEmf0SdoAY7QPgq_vBhZgbusSlyJMX2el1xc_2025-09-03';
    const locationId = 'rGAc76DxU9TQhcJy21h0';
    
    const tasksSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId)
      .collection('tasks')
      .where('taskName', '==', 'check fridge temps')
      .get();
    
    console.log(`   Found ${tasksSnapshot.docs.length} fridge tasks`);
    
    for (const taskDoc of tasksSnapshot.docs) {
      const taskData = taskDoc.data();
      console.log(`\n   🎯 FRIDGE TASK ANALYSIS:`);
      console.log(`      Document ID: ${taskDoc.id}`);
      console.log(`      Task Name: ${taskData.taskName}`);
      console.log(`      Task PhotoRequired: ${taskData.photoRequired}`);
      console.log(`      Template Task ID: ${taskData.templateTaskId}`);
      console.log(`      Completed: ${taskData.completed}`);
      
      // Apply the same fallback logic as in the Flutter app
      let finalPhotoRequired = taskData.photoRequired === true;
      
      console.log(`\n   🔄 APPLYING FALLBACK LOGIC:`);
      console.log(`      Step 1: Task photoRequired = ${taskData.photoRequired} → ${finalPhotoRequired}`);
      
      if (!finalPhotoRequired && taskData.templateTaskId && templateTaskSnap.exists) {
        const templateData = templateTaskSnap.data();
        if (templateData.photoRequired === true) {
          finalPhotoRequired = true;
          console.log(`      Step 2: Template photoRequired = ${templateData.photoRequired} → FALLBACK APPLIED`);
        } else {
          console.log(`      Step 2: Template photoRequired = ${templateData.photoRequired} → No fallback needed`);
        }
      } else if (!taskData.templateTaskId) {
        console.log(`      Step 2: No templateTaskId → Cannot apply fallback`);
      }
      
      console.log(`\n   📸 FINAL RESULT: photoRequired = ${finalPhotoRequired}`);
      console.log(`   🎯 This task ${finalPhotoRequired ? 'SHOULD' : 'should NOT'} appear in photo required filter`);
      
      if (finalPhotoRequired && !taskData.completed) {
        console.log(`   ✅ SUCCESS: This incomplete photo-required task should be visible in the filter!`);
      }
    }
    
  } catch (error) {
    console.error(`❌ Error debugging task:`, error);
  }
}

debugSpecificTask()
  .then(() => {
    console.log(`\n✅ Debug completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Debug failed:`, error);
    process.exit(1);
  });
