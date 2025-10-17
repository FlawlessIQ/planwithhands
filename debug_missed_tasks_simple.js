// Debug script for missed tasks issue
// User with multiple jobTypes cannot see missed tasks
// Organization: 3qjYzHagWmfbnMieJ1aj
// Run: node debug_missed_tasks_simple.js

const admin = require('firebase-admin');

// Check if already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

// Use the 'planwithhands' database instead of '(default)'
const db = admin.firestore();
db.settings({
  databaseId: 'planwithhands'
});

async function main() {
  console.log('🔍 Debugging Missed Tasks Issue for User with Multiple JobTypes');
  console.log('Organization: 3qjYzHagWmfbnMieJ1aj');
  console.log('═'.repeat(80));

  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  // Get organization info
  console.log('\n📋 Organization Info:');
  const orgDoc = await db.collection('organizations').doc(orgId).get();
  if (orgDoc.exists) {
    const data = orgDoc.data();
    console.log(`  Name: ${data.organizationName || 'N/A'}`);
  }

  // Get all locations
  console.log('\n📍 Locations:');
  const locationsSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .get();
  
  console.log(`  Found ${locationsSnap.size} locations`);
  for (const loc of locationsSnap.docs) {
    const data = loc.data();
    console.log(`    - ${loc.id}: ${data.locationName || 'Unnamed'}`);
  }

  // Get all users for this organization
  console.log('\n👥 Users in Organization:');
  const usersSnap = await db
    .collection('users')
    .where('organizationId', '==', orgId)
    .get();
  
  console.log(`  Found ${usersSnap.size} users`);
  for (const user of usersSnap.docs) {
    const data = user.data();
    const role = data.userRole || 0;
    const roleStr = role === 0 ? 'Staff' : (role === 1 ? 'Manager' : 'Admin');
    console.log(`    - ${data.firstName} ${data.lastName} (${data.emailAddress})`);
    console.log(`      Role: ${roleStr} (${role})`);
    console.log(`      JobTypes: ${JSON.stringify(data.jobTypes || data.jobType || 'None')}`);
    console.log(`      UID: ${user.id}`);
  }

  // Check yesterday's missed tasks
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
  
  console.log(`\n📅 Yesterday: ${yesterdayStr}`);

  // For each location, check yesterday's checklists and tasks
  for (const loc of locationsSnap.docs) {
    console.log(`\n🏢 Location: ${loc.data().locationName} (${loc.id})`);
    
    const checklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(loc.id)
      .collection('daily_checklists')
      .where('date', '==', yesterdayStr)
      .get();
    
    console.log(`  Found ${checklistsSnap.size} checklists for yesterday`);
    
    let totalTasks = 0;
    let missedTasks = 0;
    const missedByJobType = {};
    
    const checklistJobTypesMap = {};
    
    for (const checklist of checklistsSnap.docs) {
      const clData = checklist.data();
      const jobTypes = clData.jobTypes || clData.jobType;
      const jobTypesList = Array.isArray(jobTypes) ? jobTypes : (jobTypes ? [jobTypes] : []);
      
      checklistJobTypesMap[checklist.id] = jobTypesList;
      
      // Try subcollection first
      const tasksSnap = await checklist.ref.collection('tasks').get();
      let tasks = [];
      
      if (tasksSnap.size > 0) {
        tasks = tasksSnap.docs.map(d => d.data());
      } else {
        // Fallback to embedded tasks
        const tasksData = clData.tasks;
        if (Array.isArray(tasksData)) {
          tasks = tasksData;
        }
      }
      
      for (const task of tasks) {
        totalTasks++;
        const completed = task.completed === true || task.isCompleted === true;
        const isCarryForward = task.isCarryForward === true;
        
        if (!completed && !isCarryForward) {
          missedTasks++;
          
          // Track by jobType
          for (const jt of jobTypesList) {
            const jtStr = String(jt);
            missedByJobType[jtStr] = (missedByJobType[jtStr] || 0) + 1;
          }
        }
      }
    }
    
    console.log('  Checklists and their jobTypes:');
    for (const [clId, jts] of Object.entries(checklistJobTypesMap)) {
      console.log(`    - ${clId}: ${jts.length > 0 ? JSON.stringify(jts) : '(EMPTY - Staff cannot see!)'}`);
    }
    
    console.log(`  Total tasks: ${totalTasks}`);
    console.log(`  Missed tasks (not completed, not carry-forward): ${missedTasks}`);
    if (Object.keys(missedByJobType).length > 0) {
      console.log('  Missed tasks by jobType:');
      for (const [jt, count] of Object.entries(missedByJobType)) {
        console.log(`    - ${jt}: ${count} tasks`);
      }
    }
  }

  // Check today's carry-forward tasks
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  console.log(`\n📅 Today: ${todayStr}`);
  console.log('\n🔄 Carry-Forward Tasks (should contain yesterday\'s missed tasks):');

  for (const loc of locationsSnap.docs) {
    console.log(`\n🏢 Location: ${loc.data().locationName} (${loc.id})`);
    
    const checklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(loc.id)
      .collection('daily_checklists')
      .where('date', '==', todayStr)
      .get();
    
    let carryForwardCount = 0;
    const cfByJobType = {};
    const cfChecklistJobTypesMap = {};
    
    for (const checklist of checklistsSnap.docs) {
      const clData = checklist.data();
      const jobTypes = clData.jobTypes || clData.jobType;
      const jobTypesList = Array.isArray(jobTypes) ? jobTypes : (jobTypes ? [jobTypes] : []);
      
      cfChecklistJobTypesMap[checklist.id] = jobTypesList;
      
      // Check for carry-forward tasks
      const tasksSnap = await checklist.ref
        .collection('tasks')
        .where('isCarryForward', '==', true)
        .get();
      
      for (const task of tasksSnap.docs) {
        const data = task.data();
        const originalDate = data.originalDate;
        
        // Check if it's from yesterday
        let isFromYesterday = false;
        if (typeof originalDate === 'string' && originalDate === yesterdayStr) {
          isFromYesterday = true;
        } else if (originalDate && originalDate.toDate) {
          const origDate = originalDate.toDate();
          const origStr = `${origDate.getFullYear()}-${String(origDate.getMonth() + 1).padStart(2, '0')}-${String(origDate.getDate()).padStart(2, '0')}`;
          if (origStr === yesterdayStr) {
            isFromYesterday = true;
          }
        }
        
        if (isFromYesterday) {
          carryForwardCount++;
          
          // Track by jobType
          for (const jt of jobTypesList) {
            const jtStr = String(jt);
            cfByJobType[jtStr] = (cfByJobType[jtStr] || 0) + 1;
          }
        }
      }
    }
    
    console.log('  Today\'s checklists and their jobTypes:');
    for (const [clId, jts] of Object.entries(cfChecklistJobTypesMap)) {
      console.log(`    - ${clId}: ${jts.length > 0 ? JSON.stringify(jts) : '(EMPTY - Staff cannot see!)'}`);
    }
    
    console.log(`  Carry-forward tasks from yesterday: ${carryForwardCount}`);
    if (Object.keys(cfByJobType).length > 0) {
      console.log('  Carry-forward tasks by jobType:');
      for (const [jt, count] of Object.entries(cfByJobType)) {
        console.log(`    - ${jt}: ${count} tasks`);
      }
    }
  }

  console.log('\n' + '═'.repeat(80));
  console.log('🎯 Summary:');
  console.log('  If carry-forward tasks exist but users cannot see them,');
  console.log('  the issue is likely in the jobTypes filtering logic.');
  console.log('  Check:');
  console.log('    1. User\'s jobTypes field is properly saved (not empty)');
  console.log('    2. Checklist jobTypes match user jobTypes (case-sensitive!)');
  console.log('    3. jobTypes filtering logic in loadMissedTasksForToday');
  console.log('═'.repeat(80));
  
  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
