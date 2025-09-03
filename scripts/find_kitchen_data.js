#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function findKitchenData() {
  try {
    console.log('🔍 Searching for "Kitchen opening list" or "check fridge temps"...\n');
    
    const orgsSnapshot = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnapshot.docs) {
      console.log(`\n📍 Organization: ${orgDoc.id}`);
      
      // Search templates
      const templatesSnapshot = await db
        .collection('organizations')
        .doc(orgDoc.id)
        .collection('checklist_templates')
        .get();
      
      for (const templateDoc of templatesSnapshot.docs) {
        const templateData = templateDoc.data();
        const templateName = templateData.name || templateData.checklistName || 'Unnamed';
        
        if (templateName.toLowerCase().includes('kitchen')) {
          console.log(`   📋 Found template: ${templateName} (${templateDoc.id})`);
          console.log(`      Full template data:`, JSON.stringify(templateData, null, 2));
          
          // Check tasks (both formats)
          let templateTasks = [];
          
          if (templateData.tasks && Array.isArray(templateData.tasks)) {
            templateTasks = templateData.tasks;
            console.log(`      Tasks (document): ${templateTasks.length}`);
          } else {
            const tasksSnapshot = await templateDoc.ref.collection('tasks').get();
            templateTasks = tasksSnapshot.docs.map(doc => ({id: doc.id, ...doc.data()}));
            console.log(`      Tasks (subcollection): ${templateTasks.length}`);
          }
          
          templateTasks.forEach((task, idx) => {
            const name = task.taskName || task.name || `Task ${idx + 1}`;
            console.log(`        Task: "${name}" | photoRequired: ${task.photoRequired} | Full data:`, JSON.stringify(task, null, 2));
          });
        }
      }
      
      // Search locations and daily checklists
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgDoc.id)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const dailyChecklistsSnapshot = await locationDoc.ref.collection('daily_checklists').get();
        
        for (const dailyDoc of dailyChecklistsSnapshot.docs) {
          const dailyData = dailyDoc.data();
          const checklistName = dailyData.checklistName || dailyData.name || 'Unnamed';
          
          if (checklistName.toLowerCase().includes('kitchen')) {
            console.log(`   📅 Found daily checklist: ${checklistName} (${dailyDoc.id})`);
            console.log(`      Date: ${dailyData.date}`);
            console.log(`      Full daily data:`, JSON.stringify(dailyData, null, 2));
            
            // Check tasks
            let dailyTasks = [];
            
            if (dailyData.tasks && Array.isArray(dailyData.tasks)) {
              dailyTasks = dailyData.tasks;
              console.log(`      Tasks (document): ${dailyTasks.length}`);
            } else {
              const tasksSnapshot = await dailyDoc.ref.collection('tasks').get();
              dailyTasks = tasksSnapshot.docs.map(doc => ({id: doc.id, ...doc.data()}));
              console.log(`      Tasks (subcollection): ${dailyTasks.length}`);
            }
            
            dailyTasks.forEach((task, idx) => {
              const name = task.taskName || task.name || `Task ${idx + 1}`;
              if (name.toLowerCase().includes('fridge') || name.toLowerCase().includes('temp')) {
                console.log(`        ✨ FOUND TARGET TASK: "${name}"`);
                console.log(`        Full task data:`, JSON.stringify(task, null, 2));
              } else {
                console.log(`        Task: "${name}" | photoRequired: ${task.photoRequired}`);
              }
            });
          }
        }
      }
    }
    
  } catch (error) {
    console.error(`❌ Error searching for kitchen data:`, error);
  }
}

findKitchenData()
  .then(() => {
    console.log(`\n🎉 Kitchen data search completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Search failed:`, error);
    process.exit(1);
  });
