#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function searchAllTasks() {
  try {
    console.log('🔍 Searching ALL tasks for photo-related data...\n');
    
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`Found ${orgsSnapshot.docs.length} organizations\n`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      console.log(`📍 Organization: ${orgDoc.id}`);
      
      // Search ALL templates
      const templatesSnapshot = await db
        .collection('organizations')
        .doc(orgDoc.id)
        .collection('checklist_templates')
        .get();
      
      for (const templateDoc of templatesSnapshot.docs) {
        const templateData = templateDoc.data();
        const templateName = templateData.name || templateData.checklistName || 'Unnamed';
        console.log(`   📋 Template: ${templateName} (${templateDoc.id})`);
        
        // Check tasks (both formats)
        let templateTasks = [];
        
        if (templateData.tasks && Array.isArray(templateData.tasks)) {
          templateTasks = templateData.tasks;
          console.log(`      Tasks (document): ${templateTasks.length}`);
          
          templateTasks.forEach((task, idx) => {
            const name = task.taskName || task.name || `Task ${idx + 1}`;
            const photoRequired = task.photoRequired === true;
            console.log(`        "${name}" | photoRequired: ${photoRequired}`);
            if (photoRequired) console.log(`          ✨ PHOTO REQUIRED TEMPLATE TASK!`);
          });
        } else {
          const tasksSnapshot = await templateDoc.ref.collection('tasks').get();
          console.log(`      Tasks (subcollection): ${tasksSnapshot.docs.length}`);
          
          tasksSnapshot.docs.forEach((taskDoc) => {
            const task = taskDoc.data();
            const name = task.taskName || task.name || taskDoc.id;
            const photoRequired = task.photoRequired === true;
            console.log(`        "${name}" | photoRequired: ${photoRequired}`);
            if (photoRequired) console.log(`          ✨ PHOTO REQUIRED TEMPLATE TASK!`);
          });
        }
      }
      
      // Search ALL locations and daily checklists
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgDoc.id)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationData = locationDoc.data();
        const locationName = locationData.name || locationData.locationName || 'Unnamed Location';
        console.log(`   📍 Location: ${locationName} (${locationDoc.id})`);
        
        // Get recent daily checklists
        const dailyChecklistsSnapshot = await locationDoc.ref
          .collection('daily_checklists')
          .orderBy('date', 'desc')
          .limit(5)
          .get();
        
        console.log(`      Daily checklists: ${dailyChecklistsSnapshot.docs.length}`);
        
        for (const dailyDoc of dailyChecklistsSnapshot.docs) {
          const dailyData = dailyDoc.data();
          const checklistName = dailyData.checklistName || dailyData.name || 'Unnamed';
          console.log(`      📅 Daily: ${checklistName} (${dailyData.date || 'no date'})`);
          
          // Check tasks
          let dailyTasks = [];
          
          if (dailyData.tasks && Array.isArray(dailyData.tasks)) {
            dailyTasks = dailyData.tasks;
            console.log(`         Tasks (document): ${dailyTasks.length}`);
            
            dailyTasks.forEach((task, idx) => {
              const name = task.taskName || task.name || `Task ${idx + 1}`;
              const photoRequired = task.photoRequired === true;
              console.log(`           "${name}" | photoRequired: ${photoRequired}`);
              if (photoRequired) console.log(`             ✨ PHOTO REQUIRED DAILY TASK!`);
            });
          } else {
            const tasksSnapshot = await dailyDoc.ref.collection('tasks').get();
            console.log(`         Tasks (subcollection): ${tasksSnapshot.docs.length}`);
            
            tasksSnapshot.docs.forEach((taskDoc) => {
              const task = taskDoc.data();
              const name = task.taskName || task.name || taskDoc.id;
              const photoRequired = task.photoRequired === true;
              console.log(`           "${name}" | photoRequired: ${photoRequired}`);
              if (photoRequired) console.log(`             ✨ PHOTO REQUIRED DAILY TASK!`);
            });
          }
        }
      }
    }
    
  } catch (error) {
    console.error(`❌ Error searching all tasks:`, error);
  }
}

searchAllTasks()
  .then(() => {
    console.log(`\n🎉 All tasks search completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Search failed:`, error);
    process.exit(1);
  });
