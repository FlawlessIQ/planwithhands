const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com'
  });
}

const db = admin.firestore();

async function generateMissingDailyChecklists() {
  try {
    console.log('🔧 Generating missing daily checklists for Chickies Pre Dinner shift...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = 'abTp8sjidL5QVirAewe6';
    const shiftId = 'JLo4mc11PpjK9HOdRcdV';
    const date = '2025-09-29';
    
    // Get the shift document to find assigned templates
    const shiftDoc = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('shifts')
      .doc(shiftId)
      .get();
    
    if (!shiftDoc.exists) {
      console.log('❌ Pre Dinner shift not found!');
      return;
    }
    
    const shiftData = shiftDoc.data();
    const assignedTemplates = shiftData.assignedTemplates || [];
    
    console.log(`📝 Found ${assignedTemplates.length} templates assigned to Pre Dinner shift:`);
    
    const batch = db.batch();
    let createdCount = 0;
    
    for (const templateId of assignedTemplates) {
      // Get template data
      const templateDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('templates')
        .doc(templateId)
        .get();
      
      if (!templateDoc.exists) {
        console.log(`❌ Template ${templateId} not found, skipping...`);
        continue;
      }
      
      const templateData = templateDoc.data();
      console.log(`\n   Processing: ${templateData.name}`);
      console.log(`   Job Types: ${JSON.stringify(templateData.jobTypes || [])}`);
      
      // Create daily checklist document ID
      const dailyChecklistId = `${orgId}_${locationId}_${shiftId}_${templateId}_${date}`;
      
      // Check if daily checklist already exists
      const existingDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId)
        .get();
      
      if (existingDoc.exists) {
        console.log(`   ✅ Daily checklist already exists, skipping...`);
        continue;
      }
      
      // Create daily checklist data
      const dailyChecklistData = {
        templateId: templateId,
        templateName: templateData.name,
        shiftId: shiftId,
        shiftName: shiftData.name,
        locationId: locationId,
        organizationId: orgId,
        date: date,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        tasks: [], // Tasks will be populated from template
        jobTypes: templateData.jobTypes || [],
        isActive: true
      };
      
      // Add to batch
      const dailyChecklistRef = db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId);
      
      batch.set(dailyChecklistRef, dailyChecklistData);
      createdCount++;
      
      console.log(`   ✅ Prepared daily checklist for creation`);
      console.log(`   Document ID: ${dailyChecklistId}`);
    }
    
    if (createdCount > 0) {
      console.log(`\n🚀 Creating ${createdCount} daily checklists...`);
      await batch.commit();
      console.log(`✅ Successfully created ${createdCount} daily checklists!`);
      
      // Now copy tasks from templates to daily checklists
      console.log(`\n📋 Copying tasks from templates to daily checklists...`);
      
      for (const templateId of assignedTemplates) {
        const dailyChecklistId = `${orgId}_${locationId}_${shiftId}_${templateId}_${date}`;
        
        // Get template tasks
        const templateTasksSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('templates')
          .doc(templateId)
          .collection('tasks')
          .orderBy('order')
          .get();
        
        if (!templateTasksSnapshot.empty) {
          const taskBatch = db.batch();
          
          templateTasksSnapshot.forEach((taskDoc) => {
            const taskData = taskDoc.data();
            
            // Create task in daily checklist
            const dailyTaskRef = db.collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(locationId)
              .collection('daily_checklists')
              .doc(dailyChecklistId)
              .collection('tasks')
              .doc(taskDoc.id);
            
            const dailyTaskData = {
              ...taskData,
              completed: false,
              completedAt: null,
              completedBy: null,
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            };
            
            taskBatch.set(dailyTaskRef, dailyTaskData);
          });
          
          await taskBatch.commit();
          console.log(`   ✅ Copied ${templateTasksSnapshot.size} tasks for template ${templateId}`);
        }
      }
      
      console.log(`\n🎉 All daily checklists and tasks created successfully!`);
      console.log(`\n📱 Try refreshing the app now - the missing checklists should appear.`);
      
    } else {
      console.log(`\nℹ️  No new daily checklists needed to be created.`);
    }
    
  } catch (error) {
    console.error('Error generating daily checklists:', error);
  }
}

generateMissingDailyChecklists();