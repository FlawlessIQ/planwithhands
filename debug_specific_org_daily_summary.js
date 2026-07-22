const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
// Use the correct Firestore database (not the default)
db.settings({ databaseId: 'planwithhands' });

async function debugSpecificOrgDailySummary() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  console.log(`🔍 === DAILY SUMMARY DEBUG FOR ORG: ${orgId} ===\n`);
  
  try {
    // 1. Check organization data
    console.log('📋 Step 1: Organization Data');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (!orgDoc.exists) {
      console.log(`❌ Organization ${orgId} not found!`);
      return;
    }
    
    const orgData = orgDoc.data();
    console.log(`   Organization: ${orgData.name || 'Unnamed'}`);
    console.log(`   Created: ${orgData.createdAt?.toDate() || 'Unknown'}`);
    console.log(`   Active: ${orgData.isActive !== false ? 'Yes' : 'No'}`);
    
    // 2. Check admin users
    console.log(`\n👥 Step 2: Admin Users Check`);
    const adminUsersQuery = await db.collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', 'in', [1, 2])
      .where('isActive', '==', true)
      .get();
    
    console.log(`   Found ${adminUsersQuery.size} admin/manager users:`);
    adminUsersQuery.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.firstName || ''} ${data.lastName || ''} (${data.email || 'no email'})`);
      console.log(`     Role: ${data.userRole} | Active: ${data.isActive} | ID: ${doc.id}`);
    });
    
    if (adminUsersQuery.size === 0) {
      console.log('   🚨 CRITICAL: NO ADMIN USERS FOUND - This prevents summaries from being sent!');
      
      // Check if there are any users at all for this org
      const allUsersQuery = await db.collection('users')
        .where('organizationId', '==', orgId)
        .get();
      
      console.log(`   📊 Total users in org: ${allUsersQuery.size}`);
      allUsersQuery.forEach(doc => {
        const data = doc.data();
        console.log(`   - ${data.firstName || ''} ${data.lastName || ''}: Role ${data.userRole}, Active: ${data.isActive}`);
      });
      
      return;
    }
    
    // 3. Check locations
    console.log(`\n📍 Step 3: Locations Check`);
    const locationsQuery = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`   Found ${locationsQuery.size} locations:`);
    const timezones = new Set();
    
    for (const locationDoc of locationsQuery.docs) {
      const data = locationDoc.data();
      const locationName = data.locationName || 'Unknown';
      const timezone = data.timezone;
      console.log(`   - ${locationName} (${locationDoc.id}): ${timezone || 'NO TIMEZONE SET'}`);
      if (timezone) timezones.add(timezone);
    }
    
    if (locationsQuery.size === 0) {
      console.log('   🚨 CRITICAL: NO LOCATIONS FOUND - No checklists to summarize!');
      return;
    }
    
    console.log(`   Unique timezones: ${Array.from(timezones).join(', ')}`);
    
    // 4. Check recent daily summary logs
    console.log(`\n📅 Step 4: Daily Summary Logs (Last 7 Days)`);
    const today = new Date();
    const recentDates = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date(today);
      date.setDate(today.getDate() - i);
      const dateStr = date.toISOString().split('T')[0];
      recentDates.push(dateStr);
    }
    
    let summariesFound = 0;
    for (const dateStr of recentDates) {
      const logDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('daily_summary_logs')
        .doc(dateStr)
        .get();
      
      if (logDoc.exists) {
        summariesFound++;
        const logData = logDoc.data();
        console.log(`   ✅ ${dateStr}: Sent at ${logData.sentAt?.toDate()}`);
      } else {
        console.log(`   ❌ ${dateStr}: No summary sent`);
      }
    }
    
    console.log(`   📊 Summary: ${summariesFound}/7 days had summaries sent`);
    
    // 5. Check recent task data
    console.log(`\n📋 Step 5: Recent Task Data`);
    const checkDates = recentDates.slice(0, 3); // Check last 3 days
    
    for (const dateStr of checkDates) {
      console.log(`\n   📅 Checking ${dateStr}:`);
      let totalChecklists = 0;
      let totalTasks = 0;
      let completedTasks = 0;
      let tasksWithNotes = 0;
      let missedTasks = 0;
      
      for (const locationDoc of locationsQuery.docs) {
        const locationName = locationDoc.data().locationName || 'Unknown';
        const checklistsQuery = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationDoc.id)
          .collection('daily_checklists')
          .where('date', '==', dateStr)
          .get();
        
        console.log(`      Location ${locationName}: ${checklistsQuery.size} checklists`);
        totalChecklists += checklistsQuery.size;
        
        for (const checklistDoc of checklistsQuery.docs) {
          const checklistData = checklistDoc.data();
          const templateName = checklistData.templateName || 'Unknown';
          const shiftName = checklistData.shiftName || 'Unknown';
          
          // Check legacy tasks array
          const legacyTasks = checklistData.tasks || [];
          console.log(`        - ${templateName} (${shiftName}): ${legacyTasks.length} legacy tasks`);
          
          for (const task of legacyTasks) {
            totalTasks++;
            if (task.completed || task.isCompleted) completedTasks++;
            if (task.notes && task.notes.trim()) tasksWithNotes++;
            if (!task.completed && !task.isCompleted && task.reason) missedTasks++;
          }
          
          // Check subcollection tasks
          const subTasksQuery = await checklistDoc.ref.collection('tasks').get();
          console.log(`        - Subcollection tasks: ${subTasksQuery.size}`);
          
          for (const taskDoc of subTasksQuery.docs) {
            const task = taskDoc.data();
            totalTasks++;
            if (task.completed) completedTasks++;
            if (task.notes && task.notes.trim()) tasksWithNotes++;
            if (!task.completed && task.reason) missedTasks++;
          }
        }
      }
      
      const completionRate = totalTasks > 0 ? ((completedTasks / totalTasks) * 100).toFixed(1) : '0';
      console.log(`      📊 Summary: ${totalChecklists} checklists, ${totalTasks} tasks`);
      console.log(`          Completed: ${completedTasks}/${totalTasks} (${completionRate}%)`);
      console.log(`          With notes: ${tasksWithNotes}, Missed: ${missedTasks}`);
      
      // Check if this would meet the "meaningful content" criteria
      const hasContent = totalTasks > 0 || tasksWithNotes > 0 || missedTasks > 0;
      console.log(`          Would trigger summary: ${hasContent ? '✅ YES' : '❌ NO'} (meaningful content check)`);
    }
    
    // 6. Check recent notifications
    console.log(`\n📬 Step 6: Recent Notifications`);
    if (adminUsersQuery.size > 0) {
      const firstAdminId = adminUsersQuery.docs[0].id;
      const firstAdminName = `${adminUsersQuery.docs[0].data().firstName || ''} ${adminUsersQuery.docs[0].data().lastName || ''}`.trim();
      
      try {
        const notificationsQuery = await db.collection('userNotifications')
          .doc(firstAdminId)
          .collection('notifications')
          .where('type', '==', 'daily_summary')
          .orderBy('createdAt', 'desc')
          .limit(5)
          .get();
        
        console.log(`   Found ${notificationsQuery.size} recent daily summary notifications for ${firstAdminName}:`);
        notificationsQuery.forEach(doc => {
          const data = doc.data();
          const createdAt = data.createdAt?.toDate() || 'Unknown time';
          console.log(`   - ${createdAt}: ${data.title}`);
        });
        
      } catch (error) {
        console.log(`   ❌ Error checking notifications: ${error.message}`);
      }
    }
    
    // 7. Check shifts and timing
    console.log(`\n⏰ Step 7: Shifts and Timing`);
    const shiftsQuery = await db.collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .get();
    
    console.log(`   Found ${shiftsQuery.size} shifts:`);
    shiftsQuery.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.shiftName || 'Unnamed'}: ${data.startTime || 'No start'} - ${data.endTime || 'No end'}`);
    });
    
    // 8. Manual trigger test
    console.log(`\n🧪 Step 8: Testing Manual Summary Generation`);
    console.log(`   You can manually test by calling the Cloud Function:`);
    console.log(`   
    const functions = getFunctions();
    const triggerDailySummary = httpsCallable(functions, 'triggerDailySummary');
    const result = await triggerDailySummary({ 
      organizationId: '${orgId}',
      targetDate: '2025-09-24'  // or any recent date
    });
    `);
    
    // 9. Final analysis
    console.log(`\n🎯 Step 9: Root Cause Analysis`);
    console.log(`   Based on the investigation:`);
    
    if (adminUsersQuery.size === 0) {
      console.log(`   🚨 PRIMARY ISSUE: No admin users (userRole >= 1) found`);
      console.log(`   ✅ SOLUTION: Ensure at least one user has userRole: 1 or 2`);
    } else if (locationsQuery.size === 0) {
      console.log(`   🚨 PRIMARY ISSUE: No locations found`);
      console.log(`   ✅ SOLUTION: Create locations for this organization`);
    } else if (summariesFound === 0) {
      console.log(`   🚨 PRIMARY ISSUE: Function not executing or timezone issue`);
      console.log(`   ✅ SOLUTION: Check Cloud Function logs and timezone settings`);
    } else {
      console.log(`   ✅ Setup looks correct - ${summariesFound}/7 summaries found recently`);
      console.log(`   💡 May be working as intended (no meaningful content to report)`);
    }
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
  }
}

debugSpecificOrgDailySummary().then(() => {
  console.log('\n✅ Organization-specific debug completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Debug failed:', error);
  process.exit(1);
});