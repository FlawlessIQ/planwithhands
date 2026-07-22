const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

// Use the "planwithhands" database, not the default one
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkSpecificChecklist() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz';
    const checklistId = 'FErQ4pkcrCovJ7T6L13M_9uPGxodhJADOHTCS6Oqz_zCfZ5UigVjZ7KcqaWwWq_w4uHwRdAN1sRO5t5T3UA_2025-10-12';
    const taskId = 'w4uHwRdAN1sRO5t5T3UA_8JuJ9j12S6svk4slnyZG';
    
    console.log('🔍 Checking specific checklist from the path you provided...\n');
    
    // Try to get the specific task first
    console.log('📝 Checking task...');
    const taskRef = db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId)
      .collection('tasks').doc(taskId);
    
    const taskDoc = await taskRef.get();
    
    if (taskDoc.exists) {
      console.log('✅ Task found!');
      const taskData = taskDoc.data();
      console.log('Task data:', JSON.stringify(taskData, null, 2));
      console.log('\nKey fields:');
      console.log(`  - taskName: ${taskData.taskName}`);
      console.log(`  - isCarryForward: ${taskData.isCarryForward}`);
      console.log(`  - completed: ${taskData.completed}`);
      console.log(`  - templateTaskId: ${taskData.templateTaskId}`);
    } else {
      console.log('❌ Task not found');
    }
    
    // Check all tasks in the checklist
    console.log('\n📋 Checking all tasks in the checklist...');
    const tasksSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId)
      .collection('tasks')
      .get();
    
    console.log(`Found ${tasksSnapshot.docs.length} tasks\n`);
    
    let normalTasks = 0;
    let carryForwardTasks = 0;
    let completedTasks = 0;
    
    tasksSnapshot.docs.forEach((doc, idx) => {
      const data = doc.data();
      const isCarryForward = data.isCarryForward === true;
      const completed = data.completed === true;
      
      if (isCarryForward) {
        carryForwardTasks++;
      } else {
        normalTasks++;
      }
      
      if (completed) {
        completedTasks++;
      }
      
      if (idx < 5) {
        console.log(`Task ${idx + 1}: ${data.taskName || 'Unnamed'}`);
        console.log(`  ID: ${doc.id}`);
        console.log(`  isCarryForward: ${isCarryForward}`);
        console.log(`  completed: ${completed}`);
        console.log('');
      }
    });
    
    console.log('Summary:');
    console.log(`  Total tasks: ${tasksSnapshot.docs.length}`);
    console.log(`  Normal tasks: ${normalTasks}`);
    console.log(`  Carry-forward tasks: ${carryForwardTasks}`);
    console.log(`  Completed tasks: ${completedTasks}`);
    console.log('');
    
    if (normalTasks === 0 && tasksSnapshot.docs.length > 0) {
      console.log('⚠️  ALL TASKS ARE CARRY-FORWARD!');
      console.log('This is why they\'re not showing in the main checklist view.');
      console.log('They\'re being filtered out and should appear in "Missed Tasks" instead.');
    }
    
    // Check the checklist document
    console.log('\n📋 Checking checklist document...');
    const checklistRef = db
      .collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists').doc(checklistId);
    
    const checklistDoc = await checklistRef.get();
    
    if (checklistDoc.exists) {
      const checklistData = checklistDoc.data();
      console.log('Checklist data:');
      console.log(`  - templateName: ${checklistData.templateName}`);
      console.log(`  - checklistTemplateId: ${checklistData.checklistTemplateId}`);
      console.log(`  - date: ${checklistData.date}`);
      console.log(`  - shiftId: ${checklistData.shiftId}`);
      console.log(`  - totalItems: ${checklistData.totalItems}`);
      console.log(`  - completedItems: ${checklistData.completedItems}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

checkSpecificChecklist();
