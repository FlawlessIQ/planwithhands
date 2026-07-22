const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

async function manuallyGenerateTasks() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locId = 'sYhcOTkX1VkeoPjtPuwZ'; // Lakeside BBQ
  const date = '2025-10-15';
  const shiftId = 'OQjZHFFqrsSw0nPXpEJS'; // Closing shift
  
  console.log('\n=== MANUALLY GENERATING TASKS FOR OCTOBER 15 ===');
  console.log(`Organization: ${orgId}`);
  console.log(`Location: ${locId} (Lakeside BBQ)`);
  console.log(`Date: ${date}`);
  console.log(`Shift: ${shiftId} (Closing)`);
  console.log('');
  
  try {
    // 1. Get the shift data to find templates
    const shiftDoc = await db
      .collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .doc(shiftId)
      .get();
    
    if (!shiftDoc.exists) {
      console.log('❌ Shift not found!');
      return;
    }
    
    const shiftData = shiftDoc.data();
    const templateIds = shiftData.checklistTemplateIds || [];
    
    console.log(`Shift: ${shiftData.shiftName}`);
    console.log(`Templates assigned: ${templateIds.length}`);
    console.log('');
    
    // 2. Check which checklists already exist
    const existingChecklists = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locId)
      .collection('daily_checklists')
      .where('shiftId', '==', shiftId)
      .where('date', '==', date)
      .get();
    
    console.log(`Existing checklists for ${date}: ${existingChecklists.size}`);
    
    for (const doc of existingChecklists.docs) {
      const data = doc.data();
      console.log(`  - ${data.templateName || doc.id}`);
      
      // Check tasks in subcollection
      const tasksSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locId)
        .collection('daily_checklists')
        .doc(doc.id)
        .collection('tasks')
        .get();
      
      console.log(`    Tasks: ${tasksSnap.size} total`);
      
      // Count carry-forward vs regular
      let cfCount = 0;
      let regularCount = 0;
      tasksSnap.docs.forEach(taskDoc => {
        const taskData = taskDoc.data();
        if (taskData.isCarryForward) {
          cfCount++;
        } else {
          regularCount++;
        }
      });
      
      console.log(`    - Regular: ${regularCount}`);
      console.log(`    - Carry-forward: ${cfCount}`);
    }
    
    console.log('');
    
    // 3. For each template, check if fresh tasks exist
    for (const templateId of templateIds) {
      const templateDoc = await db
        .collection('organizations')
        .doc(orgId)
        .collection('checklist_templates')
        .doc(templateId)
        .get();
      
      if (!templateDoc.exists) {
        console.log(`⚠️  Template ${templateId} not found`);
        continue;
      }
      
      const templateData = templateDoc.data();
      const templateName = templateData.name;
      
      console.log(`\nTemplate: ${templateName} (${templateId})`);
      
      // Find the checklist for this template
      const checklistId = `${orgId}_${locId}_${shiftId}_${templateId}_${date}`;
      const existingChecklist = existingChecklists.docs.find(doc => doc.id === checklistId);
      
      if (!existingChecklist) {
        console.log(`  ❌ Checklist doesn't exist - needs to be created!`);
        continue;
      }
      
      // Check tasks
      const tasksSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locId)
        .collection('daily_checklists')
        .doc(checklistId)
        .collection('tasks')
        .get();
      
      // Count regular (non-carry-forward) tasks
      const regularTasks = tasksSnap.docs.filter(doc => !doc.data().isCarryForward);
      
      if (regularTasks.length === 0) {
        console.log(`  ❌ NO REGULAR TASKS! Only carry-forward tasks exist.`);
        console.log(`  This is why the checklist shows "0 of 0 tasks"`);
        
        // Get template tasks to create
        const templateTasksSnap = await db
          .collection('organizations')
          .doc(orgId)
          .collection('checklist_templates')
          .doc(templateId)
          .collection('tasks')
          .orderBy('order')
          .get();
        
        console.log(`  Template has ${templateTasksSnap.size} tasks defined`);
        console.log(`  Need to create ${templateTasksSnap.size} fresh tasks for today`);
      } else {
        console.log(`  ✅ Has ${regularTasks.length} regular tasks`);
      }
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  
  process.exit(0);
}

manuallyGenerateTasks();
