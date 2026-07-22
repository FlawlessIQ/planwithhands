const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function fixPreDinnerShiftTemplates() {
  try {
    console.log('🔧 Fixing Pre Dinner shift template assignments...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = 'abTp8sjidL5QVirAewe6';
    const shiftId = 'JLo4mc11PpjK9HOdRcdV';
    
    // First, find all Chickies templates with "Pre Dinner" in the name
    console.log('1. Finding Chickies Pre Dinner templates...');
    
    const templatesSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('templates')
      .get();
    
    console.log(`Found ${templatesSnapshot.size} total templates for Chickies`);
    
    const preDinnerTemplates = [];
    
    templatesSnapshot.forEach((doc) => {
      const data = doc.data();
      const templateName = data.name || '';
      
      if (templateName.toLowerCase().includes('pre dinner')) {
        preDinnerTemplates.push({
          id: doc.id,
          name: templateName,
          jobTypes: data.jobTypes || []
        });
      }
    });
    
    console.log(`\nFound ${preDinnerTemplates.length} Pre Dinner templates:`);
    preDinnerTemplates.forEach((template, index) => {
      console.log(`${index + 1}. ${template.name} (${template.id})`);
      console.log(`   Job Types: ${JSON.stringify(template.jobTypes)}`);
    });
    
    if (preDinnerTemplates.length === 0) {
      console.log('❌ No Pre Dinner templates found! Need to create them first.');
      return;
    }
    
    // Update the shift to assign these templates
    console.log(`\n2. Assigning ${preDinnerTemplates.length} templates to Pre Dinner shift...`);
    
    const templateIds = preDinnerTemplates.map(t => t.id);
    
    const shiftRef = db.collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .doc(shiftId);
    
    await shiftRef.update({
      assignedTemplates: templateIds,
      locationId: locationId, // Also fix the missing locationId
      updatedAt: new Date()
    });
    
    console.log(`✅ Successfully assigned ${templateIds.length} templates to the shift!`);
    console.log(`Template IDs: ${templateIds.join(', ')}`);
    
    // Now generate daily checklists for today
    console.log(`\n3. Generating missing daily checklists for today...`);
    
    const date = '2025-09-29';
    const batch = db.batch();
    let createdCount = 0;
    
    for (const template of preDinnerTemplates) {
      const dailyChecklistId = `${orgId}_${locationId}_${shiftId}_${template.id}_${date}`;
      
      // Check if daily checklist already exists
      const existingDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId)
        .get();
      
      if (existingDoc.exists) {
        console.log(`   ✅ Daily checklist for "${template.name}" already exists`);
        continue;
      }
      
      // Create daily checklist
      const dailyChecklistData = {
        templateId: template.id,
        templateName: template.name,
        shiftId: shiftId,
        shiftName: '(Chickie\'s) PRE DINNER SERVICE',
        locationId: locationId,
        organizationId: orgId,
        date: date,
        createdAt: new Date(),
        updatedAt: new Date(),
        jobTypes: template.jobTypes,
        isActive: true,
        tasks: []
      };
      
      const dailyChecklistRef = db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId);
      
      batch.set(dailyChecklistRef, dailyChecklistData);
      createdCount++;
      
      console.log(`   📝 Prepared daily checklist for "${template.name}"`);
    }
    
    if (createdCount > 0) {
      await batch.commit();
      console.log(`\n✅ Successfully created ${createdCount} new daily checklists!`);
      
      // Copy tasks from templates
      console.log(`\n4. Copying tasks from templates to daily checklists...`);
      
      for (const template of preDinnerTemplates) {
        const dailyChecklistId = `${orgId}_${locationId}_${shiftId}_${template.id}_${date}`;
        
        // Skip if this was already existing
        const existingDoc = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .doc(dailyChecklistId)
          .get();
        
        if (!existingDoc.exists) continue;
        
        // Get template tasks
        const templateTasksSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('templates')
          .doc(template.id)
          .collection('tasks')
          .orderBy('order')
          .get();
        
        if (!templateTasksSnapshot.empty) {
          const taskBatch = db.batch();
          
          templateTasksSnapshot.forEach((taskDoc) => {
            const taskData = taskDoc.data();
            
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
              createdAt: new Date()
            };
            
            taskBatch.set(dailyTaskRef, dailyTaskData);
          });
          
          await taskBatch.commit();
          console.log(`   ✅ Copied ${templateTasksSnapshot.size} tasks for "${template.name}"`);
        }
      }
      
      console.log(`\n🎉 All fixes complete! Try refreshing the app - all 4 Chickies Pre Dinner checklists should now appear.`);
      
    } else {
      console.log(`\nℹ️  All daily checklists already exist. The app should already show all checklists.`);
    }
    
  } catch (error) {
    console.error('Error fixing Pre Dinner templates:', error);
  }
}

fixPreDinnerShiftTemplates();