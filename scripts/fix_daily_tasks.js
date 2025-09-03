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

async function fixExistingDailyTasks() {
  console.log(`🔧 Fixing existing daily tasks to use template fallback`);
  
  const orgId = 'vnE0olvi1Tswjtdb19MI';
  const locationId = 'rGAc76DxU9TQhcJy21h0';
  const templateId = 'vBhZgbusSlyJMX2el1xc';
  const templateTaskId = '8684736526bf4e76'; // "check fridge temps"
  
  try {
    // Step 1: Find all daily checklists that use this template
    console.log(`\n🔍 Finding daily checklists for template: ${templateId}`);
    const dailyChecklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('checklistTemplateId', '==', templateId)
      .get();
    
    console.log(`   Found ${dailyChecklistsSnapshot.docs.length} daily checklists`);
    
    let updatedTasks = 0;
    
    // Step 2: For each checklist, find and fix the "check fridge temps" task
    for (const checklistDoc of dailyChecklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      console.log(`\n   📋 Processing checklist: ${checklistData.date || checklistDoc.id}`);
      
      // Get tasks in this checklist
      const tasksSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists').doc(checklistDoc.id)
        .collection('tasks')
        .where('taskName', '==', 'check fridge temps')
        .get();
      
      console.log(`      Found ${tasksSnapshot.docs.length} "check fridge temps" tasks`);
      
      // Update each matching task
      for (const taskDoc of tasksSnapshot.docs) {
        const taskData = taskDoc.data();
        console.log(`      📝 Task: ${taskData.taskName}`);
        console.log(`         Current photoRequired: ${taskData.photoRequired}`);
        console.log(`         Template Task ID: ${taskData.templateTaskId}`);
        
        // Check if this task should have photo required based on template
        if (taskData.templateTaskId === templateTaskId) {
          console.log(`         🎯 This task should have photo required (matches template task)`);
          
          // Remove the photoRequired field so the service will use template fallback
          await taskDoc.ref.update({
            photoRequired: admin.firestore.FieldValue.delete()
          });
          
          console.log(`         ✅ Removed photoRequired field - will now use template fallback`);
          updatedTasks++;
        } else if (taskData.photoRequired === false) {
          console.log(`         🔧 Removing false photoRequired field for template fallback`);
          
          // Remove the photoRequired field so the service will use template fallback
          await taskDoc.ref.update({
            photoRequired: admin.firestore.FieldValue.delete()
          });
          
          console.log(`         ✅ Removed photoRequired field - will now use template fallback`);
          updatedTasks++;
        } else {
          console.log(`         ⏭️  Task already has correct photoRequired value`);
        }
      }
    }
    
    console.log(`\n📊 SUMMARY:`);
    console.log(`   Processed ${dailyChecklistsSnapshot.docs.length} daily checklists`);
    console.log(`   Updated ${updatedTasks} tasks`);
    
    if (updatedTasks > 0) {
      console.log(`\n✅ SUCCESS: Fixed ${updatedTasks} daily tasks`);
      console.log(`   These tasks will now use the template photoRequired value via fallback logic`);
      console.log(`   The photo required indicator should now appear in the user dashboard`);
    } else {
      console.log(`\n⚠️  No tasks needed updating`);
    }
    
  } catch (error) {
    console.error(`❌ Error fixing daily tasks:`, error);
  }
}

fixExistingDailyTasks()
  .then(() => {
    console.log(`\n🎉 Fix completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Fix failed:`, error);
    process.exit(1);
  });
