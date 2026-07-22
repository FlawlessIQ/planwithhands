const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

// Use the same database connection as the actual functions
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

function formatDate(date) {
  return date.toISOString().split('T')[0];
}

async function correctDataCheck() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  console.log(`🔍 CORRECTED data check for organization ${orgId}`);
  console.log('=' .repeat(60));

  try {
    // 1. Get Organization Details (same as before)
    console.log('\n🏢 Organization Details:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log(`  Name: ${orgData.name || 'Not set'}`);
      console.log(`  Status: ${orgData.isActive ? 'Active' : 'Inactive'}`);
    } else {
      console.log('  ❌ Organization not found!');
      return;
    }

    // 2. Get Admin Users (CORRECTED QUERY - root users collection)
    console.log('\n👥 Admin Users (Corrected Query):');
    const adminUsersSnapshot = await db
      .collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', 'in', [1, 2]) // 1=manager, 2=admin
      .where('isActive', '==', true)
      .get();

    console.log(`  Found ${adminUsersSnapshot.docs.length} admin/manager users:`);
    adminUsersSnapshot.docs.forEach(doc => {
      const userData = doc.data();
      const roleName = userData.userRole === 1 ? 'Manager' : 'Admin';
      console.log(`    - ${userData.firstName || ''} ${userData.lastName || ''} (${userData.email})`);
      console.log(`      Role: ${roleName} (${userData.userRole})`);
      console.log(`      User ID: ${doc.id}`);
    });

    if (adminUsersSnapshot.docs.length === 0) {
      console.log('  ❌ No admin users found - daily summaries cannot be sent!');
    }

    // 3. Get All Users
    console.log('\n👤 All Users:');
    const allUsersSnapshot = await db
      .collection('users')
      .where('organizationId', '==', orgId)
      .get();

    console.log(`  Total users: ${allUsersSnapshot.docs.length}`);
    allUsersSnapshot.docs.forEach(doc => {
      const userData = doc.data();
      const roleNames = {1: 'Manager', 2: 'Admin', 3: 'User'};
      const roleName = roleNames[userData.userRole] || 'Unknown';
      console.log(`    - ${userData.firstName || ''} ${userData.lastName || ''} (${userData.email})`);
      console.log(`      Role: ${roleName}, Active: ${userData.isActive}`);
    });

    // 4. Get Organization Locations
    console.log('\n📍 Locations:');
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    console.log(`  Total locations: ${locationsSnapshot.docs.length}`);
    
    const locations = [];
    locationsSnapshot.docs.forEach(doc => {
      const locationData = doc.data();
      locations.push({
        id: doc.id,
        name: locationData.locationName || locationData.name || 'Unnamed',
        address: locationData.address
      });
      console.log(`    - ${locationData.locationName || locationData.name || 'Unnamed'}`);
      console.log(`      Address: ${locationData.address || 'No address'}`);
      console.log(`      Timezone: ${locationData.timezone || 'Not set'}`);
    });

    // 5. Check for recent daily checklists (CORRECTED STRUCTURE)
    console.log('\n📋 Recent Daily Checklists:');
    
    const dates = [];
    for (let i = 0; i < 7; i++) {
      const checkDate = new Date();
      checkDate.setDate(checkDate.getDate() - i);
      dates.push(formatDate(checkDate));
    }
    
    console.log(`  Checking dates: ${dates.slice(0, 3).join(', ')}...`);
    
    let foundChecklists = false;
    let totalTasksFound = 0;
    
    for (const dateStr of dates) {
      let dateHasData = false;
      
      for (const location of locations) {
        // Check the structure used by the actual function:
        // organizations/{orgId}/locations/{locationId}/daily_checklists (where date == dateStr)
        const checklistsRef = db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(location.id)
          .collection('daily_checklists')
          .where('date', '==', dateStr);
        
        const checklistsSnapshot = await checklistsRef.get();
        
        if (!checklistsSnapshot.empty) {
          if (!dateHasData) {
            console.log(`  ✅ ${dateStr}:`);
            dateHasData = true;
            foundChecklists = true;
          }
          
          console.log(`    ${location.name}: ${checklistsSnapshot.docs.length} checklists`);
          
          // Count tasks in each checklist
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            
            // Check tasks from subcollection (primary structure)
            const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
            const subcollectionTasks = tasksSnapshot.docs.length;
            
            // Check legacy tasks array
            const legacyTasks = (checklistData.tasks || []).length;
            
            const totalTasks = subcollectionTasks + legacyTasks;
            totalTasksFound += totalTasks;
            
            if (totalTasks > 0) {
              console.log(`      Checklist ${checklistDoc.id}: ${totalTasks} tasks (${subcollectionTasks} subcoll + ${legacyTasks} array)`);
              
              // Show task completion stats
              let completedTasks = 0;
              
              // Count completed from subcollection
              tasksSnapshot.docs.forEach(taskDoc => {
                const taskData = taskDoc.data();
                if (taskData.completed || taskData.isCompleted) {
                  completedTasks++;
                }
              });
              
              // Count completed from array
              (checklistData.tasks || []).forEach(taskData => {
                if (taskData.completed || taskData.isCompleted) {
                  completedTasks++;
                }
              });
              
              const completionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
              console.log(`        Completion: ${completedTasks}/${totalTasks} (${completionRate}%)`);
            }
          }
        }
      }
      
      if (!dateHasData) {
        console.log(`  ❌ ${dateStr}: No data found`);
      }
    }

    // 6. Check daily summary logs
    console.log('\n📅 Daily Summary Logs:');
    for (const dateStr of dates.slice(0, 3)) {
      const logDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('daily_summary_logs')
        .doc(dateStr)
        .get();
      
      if (logDoc.exists) {
        const logData = logDoc.data();
        console.log(`  ✅ ${dateStr}: Summary sent at ${logData.sentAt?.toDate().toLocaleString()}`);
        if (logData.recipientCount) {
          console.log(`    Recipients: ${logData.recipientCount}`);
        }
      } else {
        console.log(`  ❌ ${dateStr}: No summary log found`);
      }
    }

    // 7. Summary and Analysis
    console.log('\n📊 Analysis Summary:');
    console.log(`  Admin/Manager users: ${adminUsersSnapshot.docs.length}`);
    console.log(`  Total users: ${allUsersSnapshot.docs.length}`);
    console.log(`  Locations: ${locations.length}`);
    console.log(`  Recent checklist data found: ${foundChecklists ? 'YES' : 'NO'}`);
    console.log(`  Total tasks in recent data: ${totalTasksFound}`);

    if (adminUsersSnapshot.docs.length > 0 && foundChecklists) {
      console.log('\n✅ DIAGNOSIS: Organization setup appears correct');
      console.log('   - Has admin users to receive summaries');
      console.log('   - Has recent checklist data to summarize');
      console.log('   - Daily summaries should be working');
    } else if (adminUsersSnapshot.docs.length === 0) {
      console.log('\n🚨 ISSUE: No admin users found');
      console.log('   - This would prevent daily summaries from being sent');
    } else if (!foundChecklists) {
      console.log('\n🚨 ISSUE: No recent checklist data');
      console.log('   - Summaries would be empty or skipped');
    }

  } catch (error) {
    console.error('❌ Error in corrected data check:', error);
  }
}

// Run the check
correctDataCheck().then(() => {
  console.log('\n✅ Corrected check complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});