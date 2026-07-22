const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function createMissingChecklistsFromNewField() {
  try {
    console.log('🔍 Creating missing checklists based on new checklistTemplateIds field...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
    const preDinnerShiftId = 'JLo4mc11PpjK9HOdRcdV';
    const date = '2025-09-29';
    
    // The new template IDs from the screenshot
    const allTemplateIds = [
      'YkdHyozQMV6vE6wuqBLJ', // C Manager - Pre Dinner (exists)
      'WDeQtouts0p9jE2AB4eP', // C Busser - Pre Dinner (exists)
      '0CKWeWpsrONzgTKrtvMF', // Missing checklist 1
      'GRK7wpSsAHS2z66WFGMz'  // Missing checklist 2
    ];
    
    console.log('Template IDs from checklistTemplateIds field:');
    allTemplateIds.forEach((id, index) => {
      console.log(`${index}. ${id}`);
    });
    
    // Check which daily checklists already exist
    console.log('\n📋 Checking existing daily checklists...');
    
    for (const templateId of allTemplateIds) {
      const dailyChecklistId = `${orgId}_${chickiesLocationId}_${preDinnerShiftId}_${templateId}_${date}`;
      
      const existingDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId)
        .get();
      
      if (existingDoc.exists) {
        const data = existingDoc.data();
        console.log(`✅ EXISTS: ${data.templateName || 'Unknown'} (${templateId})`);
      } else {
        console.log(`❌ MISSING: Template ${templateId}`);
      }
    }
    
    // Try to find the templates to get their names
    console.log('\n🔍 Looking for template details...');
    
    // Check if templates are stored at organization level
    const orgTemplatesSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('templates')
      .get();
    
    const templateDetails = new Map();
    
    if (!orgTemplatesSnapshot.empty) {
      console.log('Found templates at organization level!');
      
      orgTemplatesSnapshot.forEach((doc) => {
        const data = doc.data();
        if (allTemplateIds.includes(doc.id)) {
          templateDetails.set(doc.id, {
            name: data.name || 'Unknown',
            jobTypes: data.jobTypes || [],
            locationId: data.locationId
          });
          console.log(`📝 Template ${doc.id}: ${data.name} (Location: ${data.locationId})`);
        }
      });
    }
    
    // Also check at location level
    const locationTemplatesSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('templates')
      .get();
    
    if (!locationTemplatesSnapshot.empty) {
      console.log('Found templates at location level!');
      
      locationTemplatesSnapshot.forEach((doc) => {
        const data = doc.data();
        if (allTemplateIds.includes(doc.id)) {
          templateDetails.set(doc.id, {
            name: data.name || 'Unknown',
            jobTypes: data.jobTypes || [],
            locationId: chickiesLocationId
          });
          console.log(`📝 Template ${doc.id}: ${data.name}`);
        }
      });
    }
    
    // Create missing daily checklists
    console.log('\n📝 Creating missing daily checklists...');
    
    const batch = db.batch();
    let createdCount = 0;
    
    for (const templateId of allTemplateIds) {
      const dailyChecklistId = `${orgId}_${chickiesLocationId}_${preDinnerShiftId}_${templateId}_${date}`;
      
      // Check if already exists
      const existingDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId)
        .get();
      
      if (existingDoc.exists) {
        continue; // Skip if already exists
      }
      
      const template = templateDetails.get(templateId);
      const templateName = template ? template.name : `Unknown Template ${templateId}`;
      
      console.log(`Creating daily checklist for: ${templateName}`);
      
      const dailyChecklistData = {
        templateId: templateId,
        templateName: templateName,
        shiftId: preDinnerShiftId,
        shiftName: '(Chickie\'s) PRE DINNER SERVICE',
        locationId: chickiesLocationId,
        organizationId: orgId,
        date: date,
        createdAt: new Date(),
        updatedAt: new Date(),
        jobTypes: template ? template.jobTypes : [],
        isActive: true
      };
      
      const dailyChecklistRef = db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId);
      
      batch.set(dailyChecklistRef, dailyChecklistData);
      createdCount++;
    }
    
    if (createdCount > 0) {
      await batch.commit();
      console.log(`\n✅ Successfully created ${createdCount} missing daily checklists!`);
      
      // Copy tasks from templates if they exist
      console.log('\n📋 Copying tasks from templates...');
      
      for (const templateId of allTemplateIds) {
        const dailyChecklistId = `${orgId}_${chickiesLocationId}_${preDinnerShiftId}_${templateId}_${date}`;
        
        // Check if this was a newly created checklist
        const wasCreated = !await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(chickiesLocationId)
          .collection('daily_checklists')
          .doc(dailyChecklistId)
          .get()
          .then(doc => doc.exists);
        
        if (wasCreated) continue;
        
        // Try to find and copy template tasks
        let templateTasksSnapshot = null;
        
        // Check organization level first
        if (!templateTasksSnapshot || templateTasksSnapshot.empty) {
          try {
            templateTasksSnapshot = await db.collection('organizations')
              .doc(orgId)
              .collection('templates')
              .doc(templateId)
              .collection('tasks')
              .orderBy('order')
              .get();
          } catch (error) {
            // Template doesn't exist at org level
          }
        }
        
        // Check location level
        if (!templateTasksSnapshot || templateTasksSnapshot.empty) {
          try {
            templateTasksSnapshot = await db.collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(chickiesLocationId)
              .collection('templates')
              .doc(templateId)
              .collection('tasks')
              .orderBy('order')
              .get();
          } catch (error) {
            // Template doesn't exist at location level
          }
        }
        
        if (templateTasksSnapshot && !templateTasksSnapshot.empty) {
          const taskBatch = db.batch();
          
          templateTasksSnapshot.forEach((taskDoc) => {
            const taskData = taskDoc.data();
            
            const dailyTaskRef = db.collection('organizations')
              .doc(orgId)
              .collection('locations')
              .doc(chickiesLocationId)
              .collection('daily_checklists')
              .doc(dailyChecklistId)
              .collection('tasks')
              .doc(taskDoc.id);
            
            const dailyTaskData = {
              ...taskData,
              completed: false,
              completedAt: null,
              completedBy: null,
              createdAt: new Date()
            };
            
            taskBatch.set(dailyTaskRef, dailyTaskData);
          });
          
          await taskBatch.commit();
          const template = templateDetails.get(templateId);
          console.log(`✅ Copied ${templateTasksSnapshot.size} tasks for "${template?.name || templateId}"`);
        }
      }
      
      console.log('\n🎉 All missing checklists created! Refresh the app - all 4 Chickies Pre Dinner checklists should now appear!');
      
    } else {
      console.log('\nℹ️  All daily checklists already exist.');
    }
    
  } catch (error) {
    console.error('Error creating missing checklists:', error);
  }
}

createMissingChecklistsFromNewField();