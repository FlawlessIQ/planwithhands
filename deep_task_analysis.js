const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = new Firestore({ 
  databaseId: 'planwithhands',
  projectId: 'plan-with-hands'
});

async function deepAnalyzeTaskCounting() {
  console.log('\n🔍 DEEP ANALYSIS: Hamilton Pork Task Counting Issue');
  console.log('=====================================================\n');
  
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const dateStr = '2025-10-14'; // Today's date from the summary
    
    console.log(`Organization: Hamilton Pork (${orgId})`);
    console.log(`Date: ${dateStr}`);
    console.log(`Expected missed tasks: ~447`);
    console.log(`Summary reported: 1087 missed (1434 total - 347 completed)`);
    console.log(`Discrepancy: ${1087 - 447} = 640 extra tasks (140% overcount)\n`);
    
    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`Found ${locationsSnapshot.size} locations:`);
    
    let totalTasksFound = 0;
    let totalCompletedTasks = 0;
    let totalIncompleteTasks = 0;
    let totalChecklistsFound = 0;
    
    const locationBreakdown = [];
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationId = locationDoc.id;
      const locationData = locationDoc.data();
      const locationName = locationData.locationName || 'Unknown Location';
      
      console.log(`\n📍 Location: ${locationName} (${locationId})`);
      
      // Get checklists for this location on the target date
      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .get();
      
      console.log(`   Checklists found: ${checklistsSnapshot.size}`);
      totalChecklistsFound += checklistsSnapshot.size;
      
      let locationTasks = 0;
      let locationCompleted = 0;
      let locationIncomplete = 0;
      let taskSources = { subcollection: 0, array: 0, duplicate: 0 };
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'Unknown Template';
        
        console.log(`   📋 Checklist: ${templateName}`);
        
        // METHOD 1: Count tasks from subcollection (current method)
        const tasksSubcollection = await checklistDoc.ref.collection('tasks').get();
        console.log(`      Tasks in subcollection: ${tasksSubcollection.size}`);
        taskSources.subcollection += tasksSubcollection.size;
        
        // METHOD 2: Count tasks from legacy array (if exists)
        const legacyTasks = checklistData.tasks || [];
        if (legacyTasks.length > 0) {
          console.log(`      ⚠️  Legacy tasks array: ${legacyTasks.length} tasks`);
          taskSources.array += legacyTasks.length;
        }
        
        // Analyze subcollection tasks in detail
        let checklistCompleted = 0;
        let checklistIncomplete = 0;
        let carryForwardTasks = 0;
        
        for (const taskDoc of tasksSubcollection.docs) {
          const taskData = taskDoc.data();
          const isCompleted = taskData.completed || taskData.isCompleted || false;
          const isCarryForward = taskData.isCarryForward || false;
          
          if (isCarryForward) {
            carryForwardTasks++;
          }
          
          if (isCompleted) {
            checklistCompleted++;
          } else {
            checklistIncomplete++;
          }
        }
        
        console.log(`      ✅ Completed: ${checklistCompleted}`);
        console.log(`      ❌ Incomplete: ${checklistIncomplete}`);
        if (carryForwardTasks > 0) {
          console.log(`      🔄 Carry-forward: ${carryForwardTasks}`);
        }
        
        locationTasks += tasksSubcollection.size;
        locationCompleted += checklistCompleted;
        locationIncomplete += checklistIncomplete;
      }
      
      console.log(`   📊 Location Summary:`);
      console.log(`      Total tasks: ${locationTasks}`);
      console.log(`      Completed: ${locationCompleted}`);
      console.log(`      Incomplete: ${locationIncomplete}`);
      console.log(`      Task sources - Subcollection: ${taskSources.subcollection}, Array: ${taskSources.array}`);
      
      if (taskSources.array > 0) {
        console.log(`      🚨 POTENTIAL ISSUE: Legacy task array detected!`);
      }
      
      locationBreakdown.push({
        name: locationName,
        id: locationId,
        tasks: locationTasks,
        completed: locationCompleted,
        incomplete: locationIncomplete,
        checklists: checklistsSnapshot.size,
        taskSources
      });
      
      totalTasksFound += locationTasks;
      totalCompletedTasks += locationCompleted;
      totalIncompleteTasks += locationIncomplete;
    }
    
    console.log('\n📊 OVERALL SUMMARY:');
    console.log(`Total checklists: ${totalChecklistsFound}`);
    console.log(`Total tasks found: ${totalTasksFound}`);
    console.log(`Total completed: ${totalCompletedTasks}`);
    console.log(`Total incomplete: ${totalIncompleteTasks}`);
    console.log(`Completion rate: ${totalTasksFound > 0 ? ((totalCompletedTasks / totalTasksFound) * 100).toFixed(1) : 0}%`);
    
    console.log('\n🔍 DISCREPANCY ANALYSIS:');
    console.log(`Summary reported total: 1434 tasks`);
    console.log(`Our analysis found: ${totalTasksFound} tasks`);
    console.log(`Difference: ${1434 - totalTasksFound} tasks`);
    
    console.log(`\nSummary reported completed: 347 tasks`);
    console.log(`Our analysis found completed: ${totalCompletedTasks} tasks`);
    console.log(`Difference: ${347 - totalCompletedTasks} tasks`);
    
    console.log(`\nSummary reported incomplete: 1087 tasks`);
    console.log(`Your count: ~447 tasks`);
    console.log(`Our analysis found incomplete: ${totalIncompleteTasks} tasks`);
    console.log(`Summary vs Your count: ${1087 - 447} extra`);
    console.log(`Summary vs Our analysis: ${1087 - totalIncompleteTasks} extra`);
    
    // Look for potential double-counting issues
    console.log('\n🔍 POTENTIAL ROOT CAUSES:');
    
    let totalArrayTasks = 0;
    let totalSubcollectionTasks = 0;
    
    locationBreakdown.forEach(loc => {
      totalArrayTasks += loc.taskSources.array;
      totalSubcollectionTasks += loc.taskSources.subcollection;
    });
    
    if (totalArrayTasks > 0) {
      console.log(`1. 🚨 DOUBLE COUNTING: Found ${totalArrayTasks} tasks in legacy arrays`);
      console.log(`   If function is counting both subcollection (${totalSubcollectionTasks}) AND arrays (${totalArrayTasks})`);
      console.log(`   Total would be: ${totalSubcollectionTasks + totalArrayTasks} tasks`);
      console.log(`   This could explain the overcount!`);
    }
    
    if (Math.abs(1434 - (totalSubcollectionTasks + totalArrayTasks)) < 50) {
      console.log(`2. 🎯 LIKELY CAUSE: Double counting subcollection + array tasks`);
    }
    
    console.log(`3. Check for timezone issues affecting date filtering`);
    console.log(`4. Check for carry-forward tasks being counted as current day tasks`);
    console.log(`5. Check for business-day vs calendar-day period confusion`);
    
  } catch (error) {
    console.error('❌ Error during deep analysis:', error);
  }
}

deepAnalyzeTaskCounting().then(() => {
  console.log('\n✅ Deep analysis complete');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});