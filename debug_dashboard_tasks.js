const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

async function debugDashboardTasks() {
  const orgId = 'B2BXqRWWSUMvbmJEkRBe';
  const locId = 'lakesideBBQQSMYYcZWiWKYDGNT9';
  const today = '2025-10-15'; // Today's date from screenshot
  
  console.log('\n=== DEBUGGING DASHBOARD TASK DISPLAY ===');
  console.log(`Organization: ${orgId}`);
  console.log(`Location: Lakeside BBQ (${locId})`);
  console.log(`Date: ${today}`);
  console.log('');
  
  try {
    // First check if the location exists
    console.log('0. Checking if location exists...');
    const locDoc = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locId)
      .get();
    
    if (!locDoc.exists) {
      console.log('   ❌ LOCATION NOT FOUND!');
      console.log('   Checking what locations exist...');
      const locsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      console.log(`   Found ${locsSnap.size} locations:`);
      locsSnap.docs.forEach(doc => {
        const data = doc.data();
        console.log(`      - ${data.locationName || doc.id}: ${doc.id}`);
      });
      return;
    }
    
    console.log('   ✅ Location exists: ' + locDoc.data().locationName);
    console.log('');
    
    // 1. Check if checklists exist for today
    console.log('1. Checking for checklists...');
    const checklistsRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locId)
      .collection('daily_checklists');
    
    const todayChecklists = await checklistsRef
      .where('date', '==', today)
      .get();
    
    console.log(`   Found ${todayChecklists.size} checklists for ${today}`);
    
    if (todayChecklists.empty) {
      console.log('   ❌ NO CHECKLISTS FOUND! This is the problem.');
      return;
    }
    
    console.log('');
    
    // 2. Check each checklist for tasks
    console.log('2. Checking tasks for each checklist...');
    for (const doc of todayChecklists.docs) {
      const data = doc.data();
      console.log(`\n   Checklist: ${data.templateName || doc.id}`);
      console.log(`   - ID: ${doc.id}`);
      console.log(`   - Template ID: ${data.checklistTemplateId || 'NONE'}`);
      console.log(`   - Shift: ${data.shiftName || 'Unknown'} (${data.shiftId || 'no-id'})`);
      console.log(`   - Date: ${data.date}`);
      console.log(`   - Job Types: ${JSON.stringify(data.jobTypes || data.jobType || 'NONE')}`);
      console.log(`   - Inline tasks: ${data.tasks?.length || 0}`);
      
      // Check subcollection
      const tasksSnap = await checklistsRef
        .doc(doc.id)
        .collection('tasks')
        .orderBy('order')
        .get();
      
      console.log(`   - Subcollection tasks: ${tasksSnap.size}`);
      
      if (tasksSnap.size === 0) {
        console.log('   ❌ NO TASKS IN SUBCOLLECTION!');
      } else {
        console.log('   ✅ Tasks found:');
        tasksSnap.docs.slice(0, 3).forEach((taskDoc, idx) => {
          const taskData = taskDoc.data();
          console.log(`      ${idx + 1}. ${taskData.taskName || taskData.description || taskData.name || 'Unnamed'}`);
          console.log(`         - Completed: ${taskData.completed || false}`);
          console.log(`         - Order: ${taskData.order}`);
        });
        if (tasksSnap.size > 3) {
          console.log(`      ... and ${tasksSnap.size - 3} more tasks`);
        }
      }
    }
    
    console.log('\n');
    
    // 3. Check user data
    console.log('3. Checking user assignments...');
    const usersSnap = await db.collection('users').get();
    console.log(`   Total users in system: ${usersSnap.size}`);
    
    // Find users assigned to Lakeside BBQ
    const lakesideUsers = usersSnap.docs.filter(doc => {
      const data = doc.data();
      const locations = data.locationIds || [];
      return locations.includes(locId);
    });
    
    console.log(`   Users assigned to Lakeside BBQ: ${lakesideUsers.length}`);
    
    for (const userDoc of lakesideUsers.slice(0, 5)) {
      const userData = userDoc.data();
      console.log(`\n   User: ${userData.name || userData.email || userDoc.id}`);
      console.log(`   - Role: ${userData.userRole} (0=staff, 1=manager, 2=admin)`);
      console.log(`   - Job Types: ${JSON.stringify(userData.jobTypes || userData.jobType || 'NONE')}`);
      console.log(`   - Location IDs: ${JSON.stringify(userData.locationIds || [])}`);
    }
    
    console.log('\n');
    
    // 4. Check shifts for today
    console.log('4. Checking published schedules...');
    const schedulesSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('published_schedules')
      .where('date', '==', today)
      .get();
    
    console.log(`   Found ${schedulesSnap.size} published schedules for ${today}`);
    
    if (schedulesSnap.empty) {
      console.log('   ⚠️  No published schedules found for today!');
    } else {
      for (const schedDoc of schedulesSnap.docs) {
        const schedData = schedDoc.data();
        console.log(`\n   Schedule ID: ${schedDoc.id}`);
        console.log(`   - Location: ${schedData.locationId}`);
        console.log(`   - Date: ${schedData.date}`);
        console.log(`   - Shifts: ${schedData.shifts?.length || 0}`);
        
        if (schedData.locationId === locId && schedData.shifts) {
          console.log('   - Shifts for Lakeside BBQ:');
          schedData.shifts.forEach(shift => {
            console.log(`      • ${shift.shiftName || 'Unnamed'} (${shift.shiftId || 'no-id'})`);
            console.log(`        Assigned users: ${shift.userIds?.length || 0}`);
          });
        }
      }
    }
    
    console.log('\n=== END DEBUG ===\n');
    
  } catch (error) {
    console.error('Error during debug:', error);
  }
  
  process.exit(0);
}

debugDashboardTasks();
