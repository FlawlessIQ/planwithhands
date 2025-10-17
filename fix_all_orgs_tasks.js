/**
 * FIX ALL ORGANIZATIONS - OCTOBER 15 & 16 TASKS
 * 
 * Problem: Race condition between carry-forward and daily generator functions
 *          caused all Oct 15/16 tasks to be marked as carry-forwards only
 * 
 * Solution: For every organization and location, check checklists and create
 *          missing template tasks where needed
 * 
 * Run with: FIRESTORE_DATABASE_ID=planwithhands node fix_all_orgs_tasks.js
 */

const {Firestore, Timestamp} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

console.log(`✅ Using Firestore database: ${FIRESTORE_DATABASE_ID}`);

// Dates to fix
const DATES_TO_FIX = ['2025-10-15', '2025-10-16'];

// Stats tracking
const stats = {
  orgsProcessed: 0,
  locationsProcessed: 0,
  checklistsProcessed: 0,
  checklistsFixed: 0,
  tasksCreated: 0,
  errors: 0
};

async function fixChecklistTasks(checklistDoc, orgId, locationId) {
  const checklistData = checklistDoc.data();
  const checklistId = checklistDoc.id;
  const templateId = checklistData.checklistTemplateId || checklistData.templateId;
  const templateName = checklistData.templateName;
  const date = checklistData.date;
  
  if (!templateId) {
    console.log(`  ⚠️  Checklist ${checklistId} has no templateId, skipping`);
    return 0;
  }
  
  // Check if already has template tasks
  const regularTasksSnap = await checklistDoc.ref.collection('tasks')
    .where('isCarryForward', '==', false)
    .limit(1)
    .get();
  
  if (!regularTasksSnap.empty) {
    return 0; // Already has template tasks
  }
  
  console.log(`    📝 Fixing: ${templateName} (${date})`);
  
  // Get template tasks
  const templateTasksSnap = await db.collection('organizations')
    .doc(orgId)
    .collection('checklist_templates')
    .doc(templateId)
    .collection('tasks')
    .orderBy('order')
    .get();
  
  if (templateTasksSnap.empty) {
    console.log(`      ⚠️  No tasks found in template`);
    return 0;
  }
  
  console.log(`      Creating ${templateTasksSnap.size} template tasks...`);
  
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
      dateString: date,
      organizationId: orgId,
      locationId: locationId,
      shiftId: checklistData.shiftId,
      createdAt: Timestamp.now(),
      createdBy: 'bulk-fix-script'
    };
    
    // Add optional fields
    if (templateTask.description) {
      newTask.description = templateTask.description;
    }
    
    batch.set(taskRef, newTask);
    createdCount++;
  }
  
  if (createdCount > 0) {
    try {
      await batch.commit();
      console.log(`      ✅ Created ${createdCount} tasks`);
      return createdCount;
    } catch (error) {
      console.error(`      ❌ Error creating tasks:`, error.message);
      stats.errors++;
      return 0;
    }
  }
  
  return 0;
}

async function fixLocation(orgId, orgName, locationId, locationName) {
  console.log(`\n  📍 Location: ${locationName} (${locationId})`);
  
  let locationTasksCreated = 0;
  let locationChecklistsFixed = 0;
  
  for (const date of DATES_TO_FIX) {
    // Get all checklists for this date
    const checklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .get();
    
    if (checklistsSnap.empty) {
      continue;
    }
    
    console.log(`    Date ${date}: ${checklistsSnap.size} checklists`);
    
    for (const checklistDoc of checklistsSnap.docs) {
      stats.checklistsProcessed++;
      
      try {
        const tasksCreated = await fixChecklistTasks(checklistDoc, orgId, locationId);
        if (tasksCreated > 0) {
          locationTasksCreated += tasksCreated;
          locationChecklistsFixed++;
          stats.checklistsFixed++;
          stats.tasksCreated += tasksCreated;
        }
      } catch (error) {
        console.error(`    ❌ Error processing checklist ${checklistDoc.id}:`, error.message);
        stats.errors++;
      }
    }
  }
  
  if (locationChecklistsFixed > 0) {
    console.log(`  ✅ Location summary: ${locationChecklistsFixed} checklists fixed, ${locationTasksCreated} tasks created`);
  } else {
    console.log(`  ℹ️  No fixes needed for this location`);
  }
}

async function fixOrganization(orgDoc) {
  const orgId = orgDoc.id;
  const orgData = orgDoc.data() || {};
  const orgName = orgData.name || orgId;
  
  console.log(`\n${'='.repeat(80)}`);
  console.log(`🏢 Organization: ${orgName} (${orgId})`);
  console.log(`${'='.repeat(80)}`);
  
  try {
    // Get all locations for this org
    const locationsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`Found ${locationsSnap.size} locations`);
    
    for (const locationDoc of locationsSnap.docs) {
      stats.locationsProcessed++;
      const locationId = locationDoc.id;
      const locationData = locationDoc.data() || {};
      const locationName = locationData.name || locationId;
      
      try {
        await fixLocation(orgId, orgName, locationId, locationName);
      } catch (error) {
        console.error(`  ❌ Error processing location ${locationId}:`, error.message);
        stats.errors++;
      }
    }
    
    stats.orgsProcessed++;
    
  } catch (error) {
    console.error(`❌ Error processing organization ${orgId}:`, error.message);
    stats.errors++;
  }
}

async function main() {
  console.log('\n' + '='.repeat(80));
  console.log('FIX ALL ORGANIZATIONS - OCTOBER 15 & 16 TASK GENERATION');
  console.log('='.repeat(80));
  console.log(`Dates to fix: ${DATES_TO_FIX.join(', ')}`);
  console.log(`Database: ${FIRESTORE_DATABASE_ID}`);
  console.log('='.repeat(80) + '\n');
  
  const startTime = Date.now();
  
  try {
    // Get all organizations
    const orgsSnap = await db.collection('organizations').get();
    console.log(`📊 Found ${orgsSnap.size} organizations to process\n`);
    
    for (const orgDoc of orgsSnap.docs) {
      try {
        await fixOrganization(orgDoc);
      } catch (error) {
        console.error(`❌ Fatal error processing org ${orgDoc.id}:`, error);
        stats.errors++;
      }
    }
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    stats.errors++;
  }
  
  const duration = ((Date.now() - startTime) / 1000).toFixed(2);
  
  // Print final summary
  console.log('\n' + '='.repeat(80));
  console.log('✨ FINAL SUMMARY');
  console.log('='.repeat(80));
  console.log(`Organizations processed: ${stats.orgsProcessed}`);
  console.log(`Locations processed: ${stats.locationsProcessed}`);
  console.log(`Checklists checked: ${stats.checklistsProcessed}`);
  console.log(`Checklists fixed: ${stats.checklistsFixed}`);
  console.log(`Tasks created: ${stats.tasksCreated}`);
  console.log(`Errors: ${stats.errors}`);
  console.log(`Duration: ${duration}s`);
  console.log('='.repeat(80));
  
  if (stats.tasksCreated > 0) {
    console.log('\n🔄 Refresh dashboards to see the new tasks!');
  }
  
  if (stats.errors > 0) {
    console.log('\n⚠️  Some errors occurred. Check the log above for details.');
    process.exit(1);
  }
  
  process.exit(0);
}

main();
