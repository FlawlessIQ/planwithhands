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

async function testPhotoFilter(orgId) {
  console.log(`🔍 Testing photo filter logic for org: ${orgId}`);
  
  try {
    let photoRequiredTasksFound = 0;
    let totalTasksProcessed = 0;
    
    // Get all locations for this organization
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`� Found ${locationsSnapshot.docs.length} locations`);
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationName = locationDoc.data().name || locationDoc.data().locationName || 'Unnamed Location';
      console.log(`\n📍 Processing location: ${locationName} (${locationDoc.id})`);
      
      // Get recent daily checklists (today and yesterday)
      const today = new Date();
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const todayStr = today.toISOString().split('T')[0];
      const yesterdayStr = yesterday.toISOString().split('T')[0];
      
      const dailyChecklistsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationDoc.id)
        .collection('daily_checklists')
        .where('date', 'in', [todayStr, yesterdayStr, '2025-09-03']) // Include our test date
        .get();
      
      console.log(`   📅 Found ${dailyChecklistsSnapshot.docs.length} daily checklists`);
      
      for (const checklistDoc of dailyChecklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        console.log(`\n   📋 Processing checklist: ${checklistData.checklistName || checklistDoc.id}`);
        console.log(`      Template: ${checklistData.templateName}`);
        console.log(`      Date: ${checklistData.date}`);
        
        // Get tasks for this daily checklist
        const tasksSnapshot = await db
          .collection('organizations').doc(orgId)
          .collection('locations').doc(locationDoc.id)
          .collection('daily_checklists').doc(checklistDoc.id)
          .collection('tasks').get();
        
        console.log(`      Tasks found: ${tasksSnapshot.docs.length}`);
        
        // Get template tasks for fallback logic if we have a templateId
        let templateTasks = {};
        if (checklistData.templateId) {
            try {
                const templateTasksSnapshot = await db
                    .collection('organizations').doc(orgId)
                    .collection('locations').doc(locationDoc.id)
                    .collection('checklistTemplates').doc(checklistData.templateId)
                    .collection('tasks').get();
                
                templateTasksSnapshot.docs.forEach(doc => {
                    const taskData = doc.data();
                    templateTasks[taskData.id] = taskData;
                });
                
                console.log(`      Template tasks loaded: ${Object.keys(templateTasks).length}`);
            } catch (error) {
                console.log(`      ⚠️  Error loading template tasks: ${error.message}`);
            }
        }
        
        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          totalTasksProcessed++;
          
          // Apply enhanced filtering logic with template fallback
          let finalPhotoRequired = taskData.photoRequired === true;
          
          // If no photoRequired field directly on task, check template (fallback logic)
          if (!finalPhotoRequired && taskData.id && templateTasks[taskData.id]) {
            finalPhotoRequired = templateTasks[taskData.id].photoRequired === true;
            console.log(`        🔍 Task "${taskData.name || 'Unnamed'}" using template photoRequired: ${finalPhotoRequired}`);
          }
          
          if (finalPhotoRequired) {
            photoRequiredTasksFound++;
            console.log(`        ✨ PHOTO REQUIRED TASK: "${taskData.name || 'Unnamed'}" | completed: ${taskData.completed || false} | source: ${taskData.photoRequired === true ? 'task' : 'template'}`);
          } else {
            console.log(`        📝 Regular task: "${taskData.name || 'Unnamed'}" | completed: ${taskData.completed || false}`);
          }
        }
      }
    }
    
    console.log(`\n📊 Summary:`);
    console.log(`   Total tasks processed: ${totalTasksProcessed}`);
    console.log(`   Photo required tasks found: ${photoRequiredTasksFound}`);
    console.log(`   Photo required percentage: ${totalTasksProcessed > 0 ? ((photoRequiredTasksFound / totalTasksProcessed) * 100).toFixed(1) : 0}%`);
    
    if (photoRequiredTasksFound > 0) {
      console.log(`\n✅ SUCCESS: Photo required tasks are properly identified!`);
      console.log(`   The enhanced filtering logic should now work correctly.`);
    } else {
      console.log(`\n⚠️  WARNING: No photo required tasks found.`);
      console.log(`   This might indicate an issue with the data or logic.`);
    }
    
  } catch (error) {
    console.error(`❌ Error testing photo filter:`, error);
  }
}

// Run the test
const orgId = process.argv[2] || 'multi-org';
console.log(`🚀 Testing photo filter logic`);
console.log(`📍 Organization: ${orgId}\n`);

testPhotoFilter(orgId)
  .then(() => {
    console.log(`\n🎉 Photo filter test completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Test failed:`, error);
    process.exit(1);
  });
