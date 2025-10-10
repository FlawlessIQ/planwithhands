const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

function formatDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function analyzeOneDuplicateInDetail() {
  try {
    console.log('🔍 Analyzing one checklist in detail...\n');
    
    const today = new Date();
    const todayStr = formatDate(today);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = formatDate(yesterday);
    
    // Look at Lakeside BBQ - I Manager - Pre Dinner checklist
    const orgId = 'fH9H0s0YNxvpUTKvQxR7'; // Conors pub Group
    const locationId = 'gZ6pSlkJ8b4IXMXlVLOa'; // Lakeside BBQ
    
    const checklistsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', todayStr)
      .where('templateName', '==', 'I Manager - Pre Dinner')
      .get();
    
    if (checklistsSnapshot.docs.length === 0) {
      console.log('No checklists found');
      return;
    }
    
    const checklistDoc = checklistsSnapshot.docs[0];
    console.log(`📋 Checklist: ${checklistDoc.id}`);
    console.log(`   Template: I Manager - Pre Dinner`);
    console.log(`   Date: ${todayStr}\n`);
    
    const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
    console.log(`Total tasks in subcollection: ${tasksSnapshot.docs.length}\n`);
    
    // Group by taskName
    const tasksByName = {};
    
    for (const taskDoc of tasksSnapshot.docs) {
      const taskData = taskDoc.data();
      const taskName = taskData.taskName || 'Unknown';
      const isCarryForward = taskData.isCarryForward === true;
      
      if (!tasksByName[taskName]) {
        tasksByName[taskName] = [];
      }
      
      tasksByName[taskName].push({
        docId: taskDoc.id,
        taskId: taskData.taskId,
        isCarryForward: isCarryForward,
        completed: taskData.completed === true,
        originalDate: taskData.originalDate,
        originalTaskId: taskData.originalTaskId,
        carriedIntoDate: taskData.carriedIntoDate,
        createdAt: taskData.createdAt,
      });
    }
    
    // Show duplicates
    console.log('DUPLICATE TASKS:');
    console.log('='.repeat(80));
    let duplicateCount = 0;
    
    for (const [taskName, tasks] of Object.entries(tasksByName)) {
      if (tasks.length > 1) {
        duplicateCount++;
        console.log(`\n"${taskName}" - ${tasks.length} copies:`);
        for (const task of tasks) {
          console.log(`   Doc ID: ${task.docId}`);
          console.log(`   Task ID: ${task.taskId}`);
          console.log(`   IsCarryForward: ${task.isCarryForward}`);
          console.log(`   Completed: ${task.completed}`);
          console.log(`   OriginalTaskId: ${task.originalTaskId || 'none'}`);
          console.log(`   OriginalDate: ${task.originalDate || 'none'}`);
          console.log(`   CarriedIntoDate: ${task.carriedIntoDate || 'none'}`);
          console.log(`   CreatedAt: ${task.createdAt ? new Date(task.createdAt._seconds * 1000).toISOString() : 'none'}`);
          console.log('');
        }
      }
    }
    
    console.log(`\n📊 Found ${duplicateCount} tasks with duplicates`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

analyzeOneDuplicateInDetail().then(() => {
  console.log('\nDone!');
  process.exit(0);
}).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
