const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

// Use the "planwithhands" database, not the default one
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

/**
 * Fix for the issue where all tasks are marked as isCarryForward: true
 * when they should be normal template tasks.
 * 
 * This script:
 * 1. Finds checklists where ALL tasks are carry-forward tasks
 * 2. For each checklist, gets the template tasks
 * 3. Deletes the incorrectly marked carry-forward tasks
 * 4. Seeds the proper template tasks
 */

async function fixCarryForwardTasks() {
  try {
    // From the actual Firebase path:
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // Fixed: O not 0
    const date = '2025-10-12';
    
    console.log('🔧 Fixing carry-forward tasks issue...');
    console.log(`Organization: ${orgId}`);
    console.log(`Location: ${locationId}`);
    console.log(`Date: ${date}`);
    console.log('');
    
    // Get all daily checklists for this date
    const checklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .get();
    
    console.log(`Found ${checklistsSnapshot.docs.length} checklists for ${date}`);
    console.log('');
    
    let fixed = 0;
    let skipped = 0;
    
    for (const checklistDoc of checklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      const checklistId = checklistDoc.id;
      const templateId = checklistData.checklistTemplateId || checklistData.templateId;
      const templateName = checklistData.templateName || 'Unknown Template';
      const shiftId = checklistData.shiftId;
      
      console.log(`\n${'='.repeat(80)}`);
      console.log(`📋 Checking: ${templateName}`);
      console.log(`   Checklist ID: ${checklistId}`);
      console.log(`   Template ID: ${templateId}`);
      
      // Get all tasks in this checklist
      const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
      
      if (tasksSnapshot.docs.length === 0) {
        console.log(`   ⚠️  No tasks found - will seed from template`);
      } else {
        const totalTasks = tasksSnapshot.docs.length;
        const carryForwardTasks = tasksSnapshot.docs.filter(d => d.data().isCarryForward === true);
        const normalTasks = tasksSnapshot.docs.filter(d => d.data().isCarryForward !== true);
        
        console.log(`   Total tasks: ${totalTasks}`);
        console.log(`   Carry-forward tasks: ${carryForwardTasks.length}`);
        console.log(`   Normal tasks: ${normalTasks.length}`);
        
        // If there are normal tasks, skip this checklist
        if (normalTasks.length > 0) {
          console.log(`   ✅ Checklist has normal tasks - skipping`);
          skipped++;
          continue;
        }
      }
      
      // If we get here, we need to fix this checklist
      if (!templateId) {
        console.log(`   ❌ No template ID - cannot fix`);
        skipped++;
        continue;
      }
      
      // Get the template
      const templateDoc = await db
        .collection('organizations').doc(orgId)
        .collection('checklist_templates').doc(templateId)
        .get();
      
      if (!templateDoc.exists) {
        console.log(`   ❌ Template not found - cannot fix`);
        skipped++;
        continue;
      }
      
      const templateData = templateDoc.data();
      console.log(`   ✅ Template found: ${templateData.name}`);
      
      // Get template tasks from subcollection
      const templateTasksSnapshot = await templateDoc.ref
        .collection('tasks')
        .orderBy('order')
        .get();
      
      if (templateTasksSnapshot.docs.length === 0) {
        console.log(`   ⚠️  Template has no tasks - cannot seed`);
        skipped++;
        continue;
      }
      
      console.log(`   📝 Template has ${templateTasksSnapshot.docs.length} tasks`);
      console.log(`   🔧 Fixing checklist...`);
      
      // Step 1: Delete all existing tasks (they're all carry-forward)
      console.log(`      Deleting ${tasksSnapshot.docs.length} carry-forward tasks...`);
      const deleteBatch = db.batch();
      for (const taskDoc of tasksSnapshot.docs) {
        deleteBatch.delete(taskDoc.ref);
      }
      await deleteBatch.commit();
      console.log(`      ✅ Deleted old tasks`);
      
      // Step 2: Seed proper template tasks
      console.log(`      Seeding ${templateTasksSnapshot.docs.length} template tasks...`);
      const seedBatch = db.batch();
      
      for (let i = 0; i < templateTasksSnapshot.docs.length; i++) {
        const templateTaskDoc = templateTasksSnapshot.docs[i];
        const templateTask = templateTaskDoc.data();
        const templateTaskId = templateTaskDoc.id;
        
        // Generate deterministic task ID (matching the service logic)
        const crypto = require('crypto');
        const input = `${templateTaskId}|${checklistId}|${date}`;
        const hash = crypto.createHash('sha1').update(input).digest('hex');
        const dailyTaskId = hash.substring(0, 16);
        
        const taskRef = checklistDoc.ref.collection('tasks').doc(dailyTaskId);
        
        const taskData = {
          taskId: dailyTaskId,
          taskName: templateTask.taskName || templateTask.name || templateTask.title || 'Untitled Task',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          dueDate: templateTask.dueDate || null,
          completed: false,
          isCarryForward: false, // ← THIS IS THE KEY FIX
          templateTaskId: templateTaskId,
          organizationId: orgId,
          locationId: locationId,
          dateString: date,
          shiftId: shiftId,
          checklistId: checklistId,
          dailyChecklistId: checklistId,
          checklistTemplateId: templateId,
          checklistName: templateName,
          templateName: templateName,
          order: i,
          photoRequired: templateTask.photoRequired === true,
        };
        
        seedBatch.set(taskRef, taskData);
      }
      
      await seedBatch.commit();
      console.log(`      ✅ Seeded ${templateTasksSnapshot.docs.length} new tasks`);
      
      // Step 3: Update parent checklist metrics
      await checklistDoc.ref.update({
        totalItems: templateTasksSnapshot.docs.length,
        completedItems: 0,
        isCompleted: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`   ✅ Fixed checklist successfully!`);
      fixed++;
    }
    
    console.log(`\n${'='.repeat(80)}`);
    console.log(`\n✅ Fix complete!`);
    console.log(`   Fixed: ${fixed} checklists`);
    console.log(`   Skipped: ${skipped} checklists`);
    console.log('');
    console.log(`💡 The tasks should now appear correctly in the app.`);
    console.log(`   Refresh the app to see the changes.`);
    
  } catch (error) {
    console.error('❌ Error fixing carry-forward tasks:', error);
  } finally {
    process.exit(0);
  }
}

fixCarryForwardTasks();
