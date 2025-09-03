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

async function findFridgeTask() {
  try {
    console.log('🔍 Searching for "check fridge temps" task with photo requirements...\n');
    
    const orgId = 'vnE0olvi1Tswjtdb19MI'; // From the debug logs
    console.log(`📍 Organization: ${orgId}`);
    
    // First check if templates exist in a different path
    const allOrgsSnapshot = await db.collection('organizations').doc(orgId).get();
    if (allOrgsSnapshot.exists) {
      console.log(`✅ Organization document exists`);
      console.log(`   Organization data:`, JSON.stringify(allOrgsSnapshot.data(), null, 2));
    } else {
      console.log(`❌ Organization document does not exist`);
      return;
    }
    
    // Check all possible template locations
    console.log('\n📋 Checking all possible template locations...');
    
    // Try standard checklist_templates
    const templatesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .get();
    
    console.log(`   checklist_templates collection: ${templatesSnapshot.docs.length} documents`);
    
    // Try templates (alternative naming)
    const templatesSnapshot2 = await db
      .collection('organizations')
      .doc(orgId)
      .collection('templates')
      .get();
    
    console.log(`   templates collection: ${templatesSnapshot2.docs.length} documents`);
    
    // Search in locations for daily checklists and their tasks
    console.log('\n📍 Checking locations and daily checklists...');
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`   Found ${locationsSnapshot.docs.length} locations`);
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      console.log(`\n   📍 Location: ${locationData.name || locationDoc.id}`);
      
      // Get daily checklists
      const dailyChecklistsSnapshot = await locationDoc.ref
        .collection('daily_checklists')
        .orderBy('date', 'desc')
        .limit(10)
        .get();
      
      console.log(`      Daily checklists: ${dailyChecklistsSnapshot.docs.length}`);
      
      for (const dailyDoc of dailyChecklistsSnapshot.docs) {
        const dailyData = dailyDoc.data();
        console.log(`\n      📅 Daily checklist: ${dailyData.checklistName || dailyDoc.id} (${dailyData.date})`);
        console.log(`         Template ID: ${dailyData.templateId || dailyData.checklistTemplateId || 'none'}`);
        
        // Check for fridge task in tasks subcollection
        const tasksSnapshot = await dailyDoc.ref.collection('tasks').get();
        console.log(`         Tasks in subcollection: ${tasksSnapshot.docs.length}`);
        
        let foundFridgeTask = false;
        for (const taskDoc of tasksSnapshot.docs) {
          const task = taskDoc.data();
          const taskName = task.name || task.taskName || taskDoc.id;
          
          if (taskName.toLowerCase().includes('fridge') || taskName.toLowerCase().includes('temp')) {
            foundFridgeTask = true;
            console.log(`         🎯 FOUND FRIDGE TASK: "${taskName}"`);
            console.log(`            Task ID: ${taskDoc.id}`);
            console.log(`            photoRequired: ${task.photoRequired}`);
            console.log(`            requiresPhoto: ${task.requiresPhoto}`);
            console.log(`            requirePhoto: ${task.requirePhoto}`);
            console.log(`            templateTaskId: ${task.templateTaskId}`);
            console.log(`            Full task data:`, JSON.stringify(task, null, 2));
            
            // If templateTaskId exists, try to find the template
            if (task.templateTaskId && dailyData.templateId) {
              console.log(`\n         🔍 Looking for template task...`);
              try {
                const templateTaskDoc = await db
                  .collection('organizations')
                  .doc(orgId)
                  .collection('checklist_templates')
                  .doc(dailyData.templateId)
                  .collection('tasks')
                  .doc(task.templateTaskId)
                  .get();
                
                if (templateTaskDoc.exists) {
                  const templateTask = templateTaskDoc.data();
                  console.log(`         ✅ Found template task:`);
                  console.log(`            photoRequired: ${templateTask.photoRequired}`);
                  console.log(`            Full template task:`, JSON.stringify(templateTask, null, 2));
                } else {
                  console.log(`         ❌ Template task not found`);
                }
              } catch (error) {
                console.log(`         ❌ Error getting template task: ${error.message}`);
              }
            }
            
            // Also try alternative template path
            if (task.templateTaskId && dailyData.checklistTemplateId) {
              console.log(`\n         🔍 Looking for template task (alternative path)...`);
              try {
                const templateTaskDoc = await db
                  .collection('organizations')
                  .doc(orgId)
                  .collection('checklist_templates')
                  .doc(dailyData.checklistTemplateId)
                  .collection('tasks')
                  .doc(task.templateTaskId)
                  .get();
                
                if (templateTaskDoc.exists) {
                  const templateTask = templateTaskDoc.data();
                  console.log(`         ✅ Found template task (alt path):`);
                  console.log(`            photoRequired: ${templateTask.photoRequired}`);
                  console.log(`            Full template task:`, JSON.stringify(templateTask, null, 2));
                } else {
                  console.log(`         ❌ Template task not found (alt path)`);
                }
              } catch (error) {
                console.log(`         ❌ Error getting template task (alt path): ${error.message}`);
              }
            }
          }
        }
        
        if (!foundFridgeTask) {
          console.log(`         ❌ No fridge task found in this checklist`);
        }
      }
    }
    
  } catch (error) {
    console.error(`❌ Error searching for fridge task:`, error);
  }
}

findFridgeTask()
  .then(() => {
    console.log(`\n🎉 Fridge task search completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Search failed:`, error);
    process.exit(1);
  });
