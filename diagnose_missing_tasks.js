const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function diagnoseMissingTasks() {
  try {
    // From the screenshot and actual path:
    // - Organization: FErQ4pkcrCovJ7T6L13M
    // - Location: 9uPGxodhJADOHTCS6Oqz (note: JADO not JAD0)
    // - Date: 2025-10-12
    // - Checklist showing "I Server - Open (Weekday)" with tasks in Firebase but "0 of 0 tasks" in UI
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // Fixed: O not 0
    const date = '2025-10-12';
    
    console.log('🔍 Diagnosing missing tasks issue...');
    console.log(`Organization: ${orgId}`);
    console.log(`Location: ${locationId}`);
    console.log(`Date: ${date}`);
    console.log('');
    
    // Get organization info
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    const orgData = orgDoc.data();
    console.log(`✅ Organization: ${orgData.name || 'Unnamed'}`);
    console.log('');
    
    // Get location info
    const locationDoc = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .get();
    
    if (!locationDoc.exists) {
      console.log('❌ Location not found!');
      return;
    }
    const locationData = locationDoc.data();
    console.log(`✅ Location: ${locationData.name || locationData.locationName || 'Unnamed'}`);
    console.log('');
    
    // Get all daily checklists for this date
    console.log(`📋 Checking daily checklists for ${date}...`);
    const checklistsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .get();
    
    console.log(`Found ${checklistsSnapshot.docs.length} daily checklists\n`);
    
    for (const checklistDoc of checklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      const checklistId = checklistDoc.id;
      const templateId = checklistData.checklistTemplateId || checklistData.templateId;
      const templateName = checklistData.templateName || 'Unknown Template';
      
      console.log(`\n${'='.repeat(80)}`);
      console.log(`📋 Checklist: ${templateName}`);
      console.log(`   ID: ${checklistId}`);
      console.log(`   Template ID: ${templateId}`);
      console.log(`   Shift ID: ${checklistData.shiftId || 'None'}`);
      console.log(`   Date: ${checklistData.date}`);
      console.log(`   Created: ${checklistData.createdAt?.toDate()?.toISOString() || 'Unknown'}`);
      console.log('');
      
      // Check if template exists
      if (templateId) {
        const templateDoc = await db
          .collection('organizations').doc(orgId)
          .collection('checklist_templates').doc(templateId)
          .get();
        
        if (templateDoc.exists) {
          const templateData = templateDoc.data();
          console.log(`   ✅ Template exists: ${templateData.name || 'Unnamed'}`);
          console.log(`      Active: ${templateData.active !== false}`);
          console.log(`      Deleted: ${templateData.deleted === true}`);
          console.log(`      Job Types: ${JSON.stringify(templateData.jobTypes || templateData.jobType || 'None')}`);
          
          // Check template tasks subcollection
          const templateTasksSnapshot = await templateDoc.ref
            .collection('tasks')
            .get();
          
          console.log(`      Template tasks in subcollection: ${templateTasksSnapshot.docs.length}`);
          
          if (templateTasksSnapshot.docs.length > 0) {
            console.log(`      Sample template tasks:`);
            templateTasksSnapshot.docs.slice(0, 3).forEach((taskDoc, idx) => {
              const taskData = taskDoc.data();
              console.log(`         ${idx + 1}. ${taskData.taskName || taskData.name || taskDoc.id}`);
              console.log(`            photoRequired: ${taskData.photoRequired === true}`);
              console.log(`            order: ${taskData.order}`);
            });
          }
        } else {
          console.log(`   ❌ Template NOT found: ${templateId}`);
        }
      } else {
        console.log(`   ⚠️  No template ID found`);
      }
      
      console.log('');
      
      // Check inline tasks (legacy)
      const inlineTasks = checklistData.tasks || [];
      if (Array.isArray(inlineTasks)) {
        console.log(`   📝 Inline tasks (legacy): ${inlineTasks.length}`);
      } else if (typeof inlineTasks === 'object') {
        console.log(`   📝 Inline tasks (legacy map): ${Object.keys(inlineTasks).length}`);
      }
      
      // Check tasks subcollection (current)
      const tasksSnapshot = await checklistDoc.ref
        .collection('tasks')
        .get();
      
      console.log(`   📝 Tasks subcollection: ${tasksSnapshot.docs.length}`);
      
      if (tasksSnapshot.docs.length === 0) {
        console.log(`   ⚠️  WARNING: No tasks in subcollection! This is likely the issue.`);
        console.log(`   🔧 The checklist was created but tasks were not seeded from the template.`);
      } else {
        console.log(`   Tasks breakdown:`);
        let normalTasks = 0;
        let carryForwardTasks = 0;
        let completedTasks = 0;
        
        tasksSnapshot.docs.forEach(taskDoc => {
          const taskData = taskDoc.data();
          if (taskData.isCarryForward === true) {
            carryForwardTasks++;
          } else {
            normalTasks++;
          }
          if (taskData.completed === true) {
            completedTasks++;
          }
        });
        
        console.log(`      Normal tasks: ${normalTasks}`);
        console.log(`      Carry-forward tasks: ${carryForwardTasks}`);
        console.log(`      Completed tasks: ${completedTasks}`);
        console.log('');
        
        // Show sample tasks
        console.log(`   Sample tasks:`);
        tasksSnapshot.docs.slice(0, 5).forEach((taskDoc, idx) => {
          const taskData = taskDoc.data();
          const taskName = taskData.taskName || taskData.name || taskData.title || 'Unnamed';
          const isCarryForward = taskData.isCarryForward === true;
          const completed = taskData.completed === true;
          console.log(`      ${idx + 1}. ${taskName}`);
          console.log(`         ID: ${taskDoc.id}`);
          console.log(`         Carry-forward: ${isCarryForward}`);
          console.log(`         Completed: ${completed}`);
          console.log(`         photoRequired: ${taskData.photoRequired}`);
        });
      }
      
      console.log('');
      console.log(`   📊 Summary:`);
      if (tasksSnapshot.docs.length === 0 && templateId) {
        console.log(`      ❌ PROBLEM: Checklist exists but has no tasks!`);
        console.log(`      🔧 SOLUTION: Tasks need to be seeded from template ${templateId}`);
        console.log(`      💡 This can happen if:`);
        console.log(`         - Checklist was created before task seeding logic was added`);
        console.log(`         - There was an error during task seeding`);
        console.log(`         - Template had no tasks when checklist was created`);
      } else if (tasksSnapshot.docs.length > 0) {
        const normalTaskCount = tasksSnapshot.docs.filter(d => d.data().isCarryForward !== true).length;
        if (normalTaskCount === 0) {
          console.log(`      ⚠️  WARNING: All ${tasksSnapshot.docs.length} tasks are carry-forward tasks!`);
          console.log(`      💡 Carry-forward tasks are filtered out from the main checklist view.`);
          console.log(`      🔧 Template tasks may not have been seeded properly.`);
        } else {
          console.log(`      ✅ Checklist looks healthy with ${normalTaskCount} normal tasks`);
        }
      }
    }
    
    console.log(`\n${'='.repeat(80)}`);
    console.log(`\n✅ Diagnosis complete!`);
    console.log(`\n💡 RECOMMENDATIONS:`);
    console.log(`1. If tasks subcollection is empty, re-seed from template`);
    console.log(`2. If all tasks are carry-forward, check template task seeding`);
    console.log(`3. Verify template is active and not deleted`);
    console.log(`4. Check that template has tasks in its subcollection`);
    
  } catch (error) {
    console.error('Error diagnosing missing tasks:', error);
  } finally {
    process.exit(0);
  }
}

diagnoseMissingTasks();
