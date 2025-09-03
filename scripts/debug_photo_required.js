#!/usr/bin/env node

/**
 * Debug script to check photoRequired fields in checklist templates and daily checklists
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function checkPhotoRequiredData(orgId) {
  try {
    console.log(`🔍 Checking photoRequired data for organization: ${orgId}\n`);
    
    // Check checklist templates
    console.log('📋 Checking checklist templates...');
    const templatesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .get();
      
    console.log(`   Found ${templatesSnapshot.docs.length} templates:\n`);
    
    for (const templateDoc of templatesSnapshot.docs) {
      const templateData = templateDoc.data();
      console.log(`   Template: ${templateData.name || 'Unnamed'} (${templateDoc.id})`);
      
      // Check tasks in template (both old format and new subcollection)
      let templateTasks = [];
      
      // Try old format first
      if (templateData.tasks && Array.isArray(templateData.tasks)) {
        templateTasks = templateData.tasks;
        console.log(`     Tasks (document): ${templateTasks.length}`);
      } else {
        // Try new subcollection format
        const tasksSnapshot = await templateDoc.ref.collection('tasks').get();
        templateTasks = tasksSnapshot.docs.map(doc => ({id: doc.id, ...doc.data()}));
        console.log(`     Tasks (subcollection): ${templateTasks.length}`);
      }
      
      templateTasks.forEach((task, idx) => {
        const name = task.taskName || task.name || `Task ${idx + 1}`;
        const photoRequired = task.photoRequired === true;
        console.log(`       - "${name}" | photoRequired: ${photoRequired}`);
        if (photoRequired) {
          console.log(`         ✨ PHOTO REQUIRED TASK FOUND!`);
        }
      });
      
      console.log(''); // spacing
    }
    
    // Check daily checklists
    console.log('\n📅 Checking recent daily checklists...');
    
    // Get locations first
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationName = locationDoc.data().name || locationDoc.data().locationName || 'Unnamed Location';
      console.log(`\n   Location: ${locationName} (${locationDoc.id})`);
      
      // Get recent daily checklists
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
        .where('date', 'in', [todayStr, yesterdayStr])
        .get();
      
      console.log(`     Daily checklists: ${dailyChecklistsSnapshot.docs.length}`);
      
      for (const dailyDoc of dailyChecklistsSnapshot.docs) {
        const dailyData = dailyDoc.data();
        const date = dailyData.date || 'Unknown date';
        console.log(`\n     Checklist: ${dailyData.checklistName || 'Unnamed'} (${date})`);
        
        // Check tasks (both formats)
        let dailyTasks = [];
        
        if (dailyData.tasks && Array.isArray(dailyData.tasks)) {
          dailyTasks = dailyData.tasks;
          console.log(`       Tasks (document): ${dailyTasks.length}`);
        } else {
          // Check subcollection
          const tasksSnapshot = await dailyDoc.ref.collection('tasks').get();
          dailyTasks = tasksSnapshot.docs.map(doc => ({id: doc.id, ...doc.data()}));
          console.log(`       Tasks (subcollection): ${dailyTasks.length}`);
        }
        
        dailyTasks.forEach((task, idx) => {
          const name = task.taskName || task.name || `Task ${idx + 1}`;
          const photoRequired = task.photoRequired === true;
          const hasPhoto = !!(task.photoUrl || task.proofImageUrl || task.photoUrls);
          console.log(`         - "${name}" | photoRequired: ${photoRequired} | hasPhoto: ${hasPhoto}`);
          if (photoRequired) {
            console.log(`           ✨ PHOTO REQUIRED DAILY TASK!`);
          }
        });
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Get org ID from command line
const orgId = process.argv[2];
if (!orgId) {
  console.error('Usage: node debug_photo_required.js <orgId>');
  process.exit(1);
}

checkPhotoRequiredData(orgId).then(() => process.exit(0));
