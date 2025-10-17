/**
 * MANUALLY GENERATE MISSING TASKS FOR OCTOBER 15
 * 
 * Purpose: Create fresh template tasks for Bar closing and Dish Pit -Night checklists
 * that the daily generator missed.
 * 
 * Run with: FIRESTORE_DATABASE_ID=planwithhands node generate_missing_tasks_oct15.js
 */

const {Firestore, Timestamp} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

console.log(`✅ Using Firestore database: ${FIRESTORE_DATABASE_ID}`);

// Constants
const ORG_ID = '3qjYzHagWmfbnMieJ1aj';
const LOCATION_ID = 'sYhcOTkX1VkeoPjtPuwZ';
const SHIFT_ID = 'OQjZHFFqrsSw0nPXpEJS';
const DATE = '2025-10-15';

const TEMPLATES = [
  {
    id: '5e4L09wyBWDZUJROtIeT',
    name: 'Bar closing',
    checklistId: `${ORG_ID}_${LOCATION_ID}_${SHIFT_ID}_5e4L09wyBWDZUJROtIeT_${DATE}`
  },
  {
    id: 'JR599ZROMJ93uPr0S4uj',
    name: 'Dish Pit -Night',
    checklistId: `${ORG_ID}_${LOCATION_ID}_${SHIFT_ID}_JR599ZROMJ93uPr0S4uj_${DATE}`
  }
];

async function generateTasksForTemplate(templateId, templateName, checklistId) {
  console.log(`\n📝 Processing template: ${templateName} (${templateId})`);
  
  // 1. Get template tasks
  const templateTasksRef = db.collection('organizations')
    .doc(ORG_ID)
    .collection('checklist_templates')
    .doc(templateId)
    .collection('tasks');
  
  const templateTasksSnap = await templateTasksRef.orderBy('order').get();
  
  if (templateTasksSnap.empty) {
    console.log(`  ⚠️  No tasks found in template`);
    return 0;
  }
  
  console.log(`  Found ${templateTasksSnap.size} template tasks`);
  
  // 2. Get existing tasks in checklist to avoid duplicates
  const checklistRef = db.collection('organizations')
    .doc(ORG_ID)
    .collection('locations')
    .doc(LOCATION_ID)
    .collection('daily_checklists')
    .doc(checklistId);
  
  const existingTasksSnap = await checklistRef.collection('tasks')
    .where('isCarryForward', '==', false)
    .get();
  
  console.log(`  Existing regular tasks: ${existingTasksSnap.size}`);
  
  if (existingTasksSnap.size > 0) {
    console.log(`  ℹ️  Regular tasks already exist, skipping...`);
    return 0;
  }
  
  // 3. Create fresh tasks from template
  const batch = db.batch();
  let createdCount = 0;
  
  for (const templateTaskDoc of templateTasksSnap.docs) {
    const templateTask = templateTaskDoc.data();
    const taskId = `${checklistId}_${templateTaskDoc.id}`;
    const taskRef = checklistRef.collection('tasks').doc(taskId);
    
    const newTask = {
      taskId: taskId,
      checklistId: checklistId,
      templateTaskId: templateTaskDoc.id,
      title: templateTask.title || '',
      description: templateTask.description || '',
      order: templateTask.order || 0,
      isCompleted: false,
      isCarryForward: false,  // CRITICAL: NOT a carry-forward task
      completedBy: null,
      completedAt: null,
      createdAt: Timestamp.now(),
      date: DATE,
      organizationId: ORG_ID,
      locationId: LOCATION_ID,
      shiftId: SHIFT_ID,
      templateId: templateId
    };
    
    batch.set(taskRef, newTask);
    createdCount++;
    console.log(`  ✅ Creating task ${createdCount}: ${newTask.title}`);
  }
  
  // 4. Commit the batch
  await batch.commit();
  console.log(`  🎉 Successfully created ${createdCount} fresh tasks`);
  
  return createdCount;
}

async function main() {
  console.log('\n=== GENERATING MISSING TASKS FOR OCTOBER 15 ===');
  console.log(`Organization: ${ORG_ID}`);
  console.log(`Location: ${LOCATION_ID} (Lakeside BBQ)`);
  console.log(`Date: ${DATE}`);
  console.log(`Shift: ${SHIFT_ID} (Closing)`);
  
  let totalCreated = 0;
  
  for (const template of TEMPLATES) {
    try {
      const count = await generateTasksForTemplate(
        template.id,
        template.name,
        template.checklistId
      );
      totalCreated += count;
    } catch (error) {
      console.error(`❌ Error processing ${template.name}:`, error);
    }
  }
  
  console.log(`\n✨ COMPLETE: Created ${totalCreated} total tasks`);
  console.log('\n🔄 Refresh your dashboard to see the tasks!');
  
  process.exit(0);
}

main().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
