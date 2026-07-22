/**
 * FIX OCTOBER 16 TASKS
 * 
 * Problem: All Oct 16 tasks are marked as carry-forwards (isCarryForward=true)
 * Solution: Generate fresh template tasks for all checklists that only have CF tasks
 * 
 * Run with: FIRESTORE_DATABASE_ID=planwithhands node fix_oct16_tasks.js
 */

const {Firestore, Timestamp} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

console.log(`✅ Using Firestore database: ${FIRESTORE_DATABASE_ID}`);

const ORG_ID = '3qjYzHagWmfbnMieJ1aj';
const LOCATION_ID = 'sYhcOTkX1VkeoPjtPuwZ';
const DATE = '2025-10-16';

async function fixChecklistTasks(checklistDoc) {
  const checklistData = checklistDoc.data();
  const checklistId = checklistDoc.id;
  const templateId = checklistData.checklistTemplateId || checklistData.templateId;
  const templateName = checklistData.templateName;
  
  if (!templateId) {
    console.log(`  ⚠️  Checklist ${checklistId} has no templateId, skipping`);
    return 0;
  }
  
  console.log(`\n📝 Processing: ${templateName} (${templateId})`);
  
  // Check if already has template tasks
  const regularTasksSnap = await checklistDoc.ref.collection('tasks')
    .where('isCarryForward', '==', false)
    .limit(1)
    .get();
  
  if (!regularTasksSnap.empty) {
    console.log(`  ✅ Already has template tasks, skipping`);
    return 0;
  }
  
  // Get template tasks
  const templateTasksSnap = await db.collection('organizations')
    .doc(ORG_ID)
    .collection('checklist_templates')
    .doc(templateId)
    .collection('tasks')
    .orderBy('order')
    .get();
  
  if (templateTasksSnap.empty) {
    console.log(`  ⚠️  No tasks found in template`);
    return 0;
  }
  
  console.log(`  Found ${templateTasksSnap.size} template tasks`);
  
  // Create fresh tasks from template
  const batch = db.batch();
  let createdCount = 0;
  
  for (const templateTaskDoc of templateTasksSnap.docs) {
    const templateTask = templateTaskDoc.data();
    const taskId = `${templateId}_${templateTaskDoc.id}`;
    const taskRef = checklistDoc.ref.collection('tasks').doc(taskId);
    
    // Check if this task ID already exists
    const existingTask = await taskRef.get();
    if (existingTask.exists) {
      console.log(`  ℹ️  Task ${taskId} already exists, skipping`);
      continue;
    }
    
    const newTask = {
      taskId: taskId,
      taskName: templateTask.name || templateTask.title || templateTask.description || 'Task',
      checklistId: checklistId,
      templateTaskId: templateTaskDoc.id,
      templateId: templateId,
      templateName: templateName,
      checklistTemplateId: templateId,
      checklistName: templateName,
      order: templateTask.order || 0,
      completed: false,
      isCompleted: false,
      isCarryForward: false,  // CRITICAL: Fresh template task
      isCarryForwardEligible: templateTask.isCarryForwardEligible === true || templateTask.photoRequired === true,
      dateString: DATE,
      organizationId: ORG_ID,
      locationId: LOCATION_ID,
      shiftId: checklistData.shiftId,
      createdAt: Timestamp.now(),
      createdBy: 'manual-fix-script'
    };
    
    // Add optional fields
    if (templateTask.description) {
      newTask.description = templateTask.description;
    }
    
    batch.set(taskRef, newTask);
    createdCount++;
    console.log(`  ✅ Creating task ${createdCount}: ${newTask.taskName}`);
  }
  
  if (createdCount > 0) {
    await batch.commit();
    console.log(`  🎉 Successfully created ${createdCount} fresh tasks`);
  }
  
  return createdCount;
}

async function main() {
  console.log('\n=== FIXING OCTOBER 16 TASKS ===');
  console.log(`Organization: ${ORG_ID}`);
  console.log(`Location: ${LOCATION_ID} (Lakeside BBQ)`);
  console.log(`Date: ${DATE}\n`);
  
  try {
    // Get all checklists for Oct 16
    const checklistsSnap = await db
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .doc(LOCATION_ID)
      .collection('daily_checklists')
      .where('date', '==', DATE)
      .get();
    
    console.log(`Found ${checklistsSnap.size} checklists for ${DATE}`);
    
    let totalCreated = 0;
    
    for (const checklistDoc of checklistsSnap.docs) {
      try {
        const count = await fixChecklistTasks(checklistDoc);
        totalCreated += count;
      } catch (error) {
        console.error(`❌ Error processing ${checklistDoc.id}:`, error.message);
      }
    }
    
    console.log(`\n✨ COMPLETE: Created ${totalCreated} total template tasks`);
    console.log('\n🔄 Refresh your dashboard to see the tasks!');
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

main();
