/**
 * Diagnose October 16 Task Generation Issue
 * 
 * Check if tasks exist for Oct 16 and verify isCarryForward flag
 */

const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

async function diagnoseOct16() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locId = 'sYhcOTkX1VkeoPjtPuwZ'; // Lakeside BBQ
  const date = '2025-10-16';
  
  console.log('\n=== DIAGNOSING OCTOBER 16 TASKS ===');
  console.log(`Organization: ${orgId}`);
  console.log(`Location: ${locId} (Lakeside BBQ)`);
  console.log(`Date: ${date}\n`);
  
  try {
    // Get all checklists for Oct 16
    const checklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .get();
    
    console.log(`Found ${checklistsSnap.size} checklists for ${date}\n`);
    
    for (const checklistDoc of checklistsSnap.docs) {
      const checklistData = checklistDoc.data();
      console.log(`Checklist: ${checklistData.templateName || checklistDoc.id}`);
      
      // Get tasks for this checklist
      const tasksSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locId)
        .collection('daily_checklists')
        .doc(checklistDoc.id)
        .collection('tasks')
        .get();
      
      console.log(`  Total tasks: ${tasksSnap.size}`);
      
      // Analyze each task
      let regularCount = 0;
      let cfCount = 0;
      let cfIntoTodayCount = 0;
      
      tasksSnap.docs.forEach(taskDoc => {
        const task = taskDoc.data();
        
        if (task.isCarryForward) {
          cfCount++;
          if (task.carriedIntoDate === date) {
            cfIntoTodayCount++;
          }
        } else {
          regularCount++;
        }
      });
      
      console.log(`    - Regular tasks (isCarryForward=false): ${regularCount}`);
      console.log(`    - Carry-forward tasks (isCarryForward=true): ${cfCount}`);
      console.log(`    - CF tasks marked as carried into ${date}: ${cfIntoTodayCount}`);
      
      // Show sample tasks
      if (tasksSnap.size > 0) {
        const firstTask = tasksSnap.docs[0].data();
        console.log(`\n    Sample task:`);
        console.log(`      title: ${firstTask.title}`);
        console.log(`      isCarryForward: ${firstTask.isCarryForward}`);
        console.log(`      carriedIntoDate: ${firstTask.carriedIntoDate || 'not set'}`);
        console.log(`      originalDate: ${firstTask.originalDate || 'not set'}`);
        console.log(`      date: ${firstTask.date}`);
        console.log(`      createdAt: ${firstTask.createdAt?.toDate ? firstTask.createdAt.toDate().toISOString() : 'not set'}`);
      }
      
      console.log('');
      
      // CRITICAL CHECK
      if (regularCount === 0 && cfIntoTodayCount > 0) {
        console.log(`  ❌ PROBLEM FOUND: All tasks are marked as carry-forwards!`);
        console.log(`     This is why the dashboard shows "0 of 0 tasks"`);
        console.log(`     These should be fresh template tasks with isCarryForward=false\n`);
      } else if (regularCount === 0) {
        console.log(`  ❌ NO REGULAR TASKS: Checklist has no fresh template tasks\n`);
      } else {
        console.log(`  ✅ OK: Has ${regularCount} regular template tasks\n`);
      }
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  
  process.exit(0);
}

diagnoseOct16();
