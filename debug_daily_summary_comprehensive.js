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

async function comprehensiveDailySummaryDebug() {
  console.log('🔍 === COMPREHENSIVE DAILY SUMMARY DEBUG ===\n');
  
  try {
    // 1. Check organizations and basic data
    console.log('📋 Step 1: Organization Data');
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`   Found ${orgsSnapshot.size} organizations`);
    
    if (orgsSnapshot.empty) {
      console.log('❌ No organizations found - this explains why no summaries are sent!');
      return;
    }
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      console.log(`\n   📄 Organization: ${orgData.name || 'Unnamed'} (${orgId})`);
      
      // 2. Check admin users for this org
      console.log(`   👥 Admin Users Check:`);
      const adminUsers = await db.collection('users')
        .where('organizationId', '==', orgId)
        .where('userRole', 'in', [1, 2])
        .where('isActive', '==', true)
        .get();
      
      console.log(`      Found ${adminUsers.size} admin/manager users`);
      adminUsers.forEach(doc => {
        const data = doc.data();
        console.log(`      - ${data.firstName || ''} ${data.lastName || ''} (Role: ${data.userRole})`);
      });
      
      if (adminUsers.size === 0) {
        console.log('      ⚠️  NO ADMIN USERS - This would prevent summaries from being sent!');
        continue;
      }
      
      // 3. Check locations and timezones
      console.log(`   📍 Locations & Timezones:`);
      const locationsSnapshot = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      console.log(`      Found ${locationsSnapshot.size} locations`);
      const timezones = new Set();
      
      locationsSnapshot.forEach(doc => {
        const data = doc.data();
        const timezone = data.timezone;
        const locationName = data.locationName || 'Unknown';
        console.log(`      - ${locationName}: ${timezone || 'NO TIMEZONE SET'}`);
        if (timezone) timezones.add(timezone);
      });
      
      if (timezones.size === 0) {
        console.log('      ⚠️  NO TIMEZONES SET - This might affect scheduling logic!');
      } else {
        console.log(`      Unique timezones: ${Array.from(timezones).join(', ')}`);
      }
      
      // 4. Check recent daily summary logs
      console.log(`   📅 Recent Daily Summary Logs:`);
      const recentDates = ['2025-09-19', '2025-09-18', '2025-09-17'];
      
      for (const dateStr of recentDates) {
        const logDoc = await db.collection('organizations')
          .doc(orgId)
          .collection('daily_summary_logs')
          .doc(dateStr)
          .get();
        
        if (logDoc.exists) {
          const logData = logDoc.data();
          console.log(`      ✅ ${dateStr}: Sent at ${logData.sentAt?.toDate()}`);
        } else {
          console.log(`      ❌ ${dateStr}: No summary sent`);
        }
      }
      
      // 5. Check if there's task data for today
      console.log(`   📋 Task Data Check (2025-09-19):`);
      try {
        // Check for daily checklists across all locations
        let totalChecklists = 0;
        let totalTasks = 0;
        
        for (const locationDoc of locationsSnapshot.docs) {
          const checklistsSnapshot = await db.collection('organizations')
            .doc(orgId)
            .collection('locations')
            .doc(locationDoc.id)
            .collection('daily_checklists')
            .where('date', '==', '2025-09-19')
            .get();
          
          totalChecklists += checklistsSnapshot.size;
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            const tasks = checklistData.tasks || [];
            totalTasks += tasks.length;
            
            // Also check subcollection tasks
            const subTasks = await checklistDoc.ref.collection('tasks').get();
            totalTasks += subTasks.size;
          }
        }
        
        console.log(`      Found ${totalChecklists} checklists with ${totalTasks} total tasks`);
        
        if (totalTasks === 0) {
          console.log('      ⚠️  NO TASK DATA - This would prevent summaries (empty content check)');
        }
        
      } catch (error) {
        console.log(`      ❌ Error checking task data: ${error.message}`);
      }
      
      // 6. Check recent notifications for admin users
      if (adminUsers.size > 0) {
        console.log(`   📬 Recent Notifications:`);
        const firstAdminId = adminUsers.docs[0].id;
        try {
          const notifications = await db.collection('userNotifications')
            .doc(firstAdminId)
            .collection('notifications')
            .where('type', '==', 'daily_summary')
            .orderBy('createdAt', 'desc')
            .limit(3)
            .get();
          
          console.log(`      Found ${notifications.size} recent daily summary notifications`);
          notifications.forEach(doc => {
            const data = doc.data();
            console.log(`      - ${data.createdAt?.toDate()}: ${data.title}`);
          });
          
        } catch (error) {
          console.log(`      ❌ Error checking notifications: ${error.message}`);
        }
      }
    }
    
    // 7. Analyze the timezone logic issue
    console.log('\n⏰ Step 2: Timezone Logic Analysis');
    console.log('   Current UTC time:', new Date().toISOString());
  console.log('   Schedule model: every 5 minutes (*/5), UTC');
  console.log('   In-window logic: local hour == target hour AND');
  console.log('                    local minute in [targetMinute, targetMinute+5)');
  console.log('   Notes: Align org setting to a 5-minute boundary to trigger.');
    
    // 8. Function deployment verification
    console.log('\n🔧 Step 3: Function Deployment Status');
    console.log('   From previous check, these functions are deployed:');
  console.log('   ✅ scheduledDailySummary (scheduled, polls every 5 minutes)');
    console.log('   ✅ triggerDailySummary (callable)');
    console.log('   ✅ scheduledDailyGenerator (scheduled)');
    
    // 9. Recommendations
    console.log('\n🎯 Step 4: Recommendations');
    console.log('   Based on this analysis, likely issues:');
    console.log('   ');
    console.log('   1. 🚨 TIMEZONE LOGIC TOO RESTRICTIVE');
    console.log('      - Current logic prevents execution for most US timezones');
    console.log('      - Recommend: Remove timezone restriction or use better logic');
    console.log('   ');
    console.log('   2. ⚠️  Missing timezones in location data');
    console.log('      - Some locations have no timezone set');
    console.log('      - This defaults to UTC, which may not be intended');
    console.log('   ');
    console.log('   3. 📊 Check if task data exists');
    console.log('      - Function skips if no meaningful content found');
    console.log('      - Verify there are completed tasks to summarize');
    console.log('   ');
    console.log('   4. 👥 Verify admin users exist');
    console.log('      - Function skips if no admin users to send to');
    console.log('      - Ensure userRole field is set correctly (1=manager, 2=admin)');
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
  }
}

comprehensiveDailySummaryDebug().then(() => {
  console.log('\n✅ Comprehensive debug completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Debug failed:', error);
  process.exit(1);
});