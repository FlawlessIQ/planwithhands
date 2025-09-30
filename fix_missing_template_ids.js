const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function fixMissingTemplateIds() {
  try {
    console.log('🔧 Fixing missing templateId fields and creating missing Pre Dinner checklists...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
    const preDinnerShiftId = 'JLo4mc11PpjK9HOdRcdV';
    const date = '2025-09-29';
    
    // Step 1: Fix missing templateId fields
    console.log('1. Fixing missing templateId fields...\n');
    
    const allChickiesQuery = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .where('date', '==', date);
    
    const allChickiesSnapshot = await allChickiesQuery.get();
    
    const batch = db.batch();
    let fixedCount = 0;
    
    allChickiesSnapshot.forEach((doc) => {
      const data = doc.data();
      
      if (!data.templateId) {
        // Extract templateId from document ID
        // Format: orgId_locationId_shiftId_templateId_date
        const docIdParts = doc.id.split('_');
        if (docIdParts.length >= 5) {
          const templateId = docIdParts[3];
          
          console.log(`Fixing "${data.templateName}": Adding templateId "${templateId}"`);
          
          batch.update(doc.ref, {
            templateId: templateId,
            updatedAt: new Date()
          });
          
          fixedCount++;
        }
      }
    });
    
    if (fixedCount > 0) {
      await batch.commit();
      console.log(`✅ Fixed ${fixedCount} checklists with missing templateId\n`);
    } else {
      console.log('No templateId fixes needed\n');
    }
    
    // Step 2: Find templates for missing Pre Dinner checklists
    console.log('2. Finding templates for missing Pre Dinner checklists...\n');
    
    const templatesSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('templates')
      .get();
    
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
    
    console.log(`Found ${preDinnerTemplates.length} Pre Dinner templates:`);
    preDinnerTemplates.forEach((template) => {
      console.log(`- ${template.name} (${template.id})`);
      console.log(`  Job Types: ${JSON.stringify(template.jobTypes)}`);
    });
    
    // Step 3: Create missing daily checklists
    console.log('\n3. Creating missing daily checklists...\n');
    
    const createBatch = db.batch();
    let createdCount = 0;
    
    for (const template of preDinnerTemplates) {
      const dailyChecklistId = `${orgId}_${chickiesLocationId}_${preDinnerShiftId}_${template.id}_${date}`;
      
      // Check if it already exists
      const existingDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId)
        .get();
      
      if (existingDoc.exists) {
        console.log(`✅ "${template.name}" already exists`);
        continue;
      }
      
      console.log(`📝 Creating daily checklist for "${template.name}"`);
      
      const dailyChecklistData = {
        templateId: template.id,
        templateName: template.name,
        shiftId: preDinnerShiftId,
        shiftName: '(Chickie\'s) PRE DINNER SERVICE',
        locationId: chickiesLocationId,
        organizationId: orgId,
        date: date,
        createdAt: new Date(),
        updatedAt: new Date(),
        jobTypes: template.jobTypes,
        isActive: true
      };
      
      const dailyChecklistRef = db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .doc(dailyChecklistId);
      
      createBatch.set(dailyChecklistRef, dailyChecklistData);
      createdCount++;
    }
    
    if (createdCount > 0) {
      await createBatch.commit();
      console.log(`✅ Created ${createdCount} new daily checklists\n`);
      
      // Step 4: Copy tasks from templates
      console.log('4. Copying tasks from templates...\n');
      
      for (const template of preDinnerTemplates) {
        const dailyChecklistId = `${orgId}_${chickiesLocationId}_${preDinnerShiftId}_${template.id}_${date}`;
        
        // Get template tasks
        const templateTasksSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(chickiesLocationId)
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
          console.log(`✅ Copied ${templateTasksSnapshot.size} tasks for "${template.name}"`);
        }
      }
    } else {
      console.log('No new daily checklists needed to be created');
    }
    
    console.log('\n🎉 All fixes complete! Refresh the app - all Chickies Pre Dinner checklists should now appear with proper templateId fields.');
    
  } catch (error) {
    console.error('Error fixing issues:', error);
  }
}

fixMissingTemplateIds();