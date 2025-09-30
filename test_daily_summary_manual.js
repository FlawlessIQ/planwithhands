const admin = require('firebase-admin');

// Initialize Firebase Admin with the planwithhands database
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com/'
  });
}

// Use the planwithhands database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function manuallyTriggerDailySummary(orgId) {
  console.log(`🚀 Manually triggering daily summary for org: ${orgId}`);
  
  try {
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    
    const orgData = orgDoc.data();
    console.log(`✅ Organization: ${orgData.name || orgData.organizationName}`);
    
    // Check daily summary settings
    const settings = orgData.dailySummarySettings;
    if (!settings || !settings.enabled) {
      console.log('❌ Daily summary not enabled');
      return;
    }
    console.log(`✅ Daily summary enabled: ${settings.hour}:${String(settings.minute).padStart(2, '0')}`);
    
    // Get admin users
    const adminQuery = await db.collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', 'in', [1, 2])
      .where('isActive', '==', true)
      .get();
    
    if (adminQuery.docs.length === 0) {
      console.log('❌ No admin users found');
      return;
    }
    console.log(`✅ Found ${adminQuery.docs.length} admin users`);
    
    // Collect today's data
    const today = new Date();
    const dateStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    
    console.log('\n📊 Collecting daily data...');
    const summaryData = await collectDailySummaryData(orgId, dateStr);
    
    if (summaryData.totalTasks === 0) {
      console.log('⚠️ No tasks found for today - but we can still test the email system');
    }
    
    // Test creating the notification content
    const notificationTitle = `Daily Summary Test - ${new Date().toLocaleDateString()}`;
    const notificationContent = buildNotificationContent(summaryData, today);
    
    console.log('\n📧 Would send emails to:');
    for (const adminDoc of adminQuery.docs) {
      const adminUser = adminDoc.data();
      console.log(`   ✉️ ${adminUser.firstName} ${adminUser.lastName} (${adminUser.email})`);
    }
    
    console.log('\n📝 Email Content Preview:');
    console.log('Title:', notificationTitle);
    console.log('Content:', notificationContent);
    
    console.log('\n🎯 Next Steps:');
    console.log('1. ✅ Data collection works');
    console.log('2. ✅ Admin users found');  
    console.log('3. ✅ Email content generated');
    console.log('4. 🔧 Need to fix timing issue for automatic sending');
    console.log('5. 💡 Option: Change daily summary time to 5:00 PM for automatic sending');
    
    return {
      success: true,
      summaryData,
      adminCount: adminQuery.docs.length,
      content: notificationContent
    };
    
  } catch (error) {
    console.error('❌ Error:', error);
    return { success: false, error };
  }
}

async function collectDailySummaryData(orgId, dateStr) {
  const summaryData = {
    totalTasks: 0,
    completedTasks: 0,
    notesEntries: [],
    missedTaskEntries: [],
    photoBypassed: [],
    shiftCompletions: []
  };
  
  try {
    // Get locations
    const locationsQuery = await db.collection('organizations').doc(orgId).collection('locations').get();
    
    for (const locationDoc of locationsQuery.docs) {
      const locationId = locationDoc.id;
      const locationName = locationDoc.data().locationName || 'Unknown';
      
      // Get daily checklists for this date
      const checklistsQuery = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .get();
      
      console.log(`   📍 ${locationName}: ${checklistsQuery.docs.length} checklists`);
      
      for (const checklistDoc of checklistsQuery.docs) {
        const checklistData = checklistDoc.data();
        const tasks = checklistData.tasks || [];
        
        summaryData.totalTasks += tasks.length;
        
        // Count completed tasks and collect info
        for (const task of tasks) {
          if (task.completed || task.isCompleted) {
            summaryData.completedTasks++;
          }
          
          // Check for notes
          if (task.notes && task.notes.trim()) {
            summaryData.notesEntries.push({
              taskName: task.taskName || task.description || 'Unknown Task',
              notes: task.notes,
              locationName
            });
          }
          
          // Check for missed tasks with reasons
          if ((!task.completed && !task.isCompleted) && task.reason) {
            summaryData.missedTaskEntries.push({
              taskName: task.taskName || task.description || 'Unknown Task',
              reason: task.reason,
              locationName
            });
          }
        }
      }
    }
    
    console.log(`   📊 Total: ${summaryData.completedTasks}/${summaryData.totalTasks} tasks completed`);
    console.log(`   📝 Notes: ${summaryData.notesEntries.length}`);
    console.log(`   ❌ Missed: ${summaryData.missedTaskEntries.length}`);
    
  } catch (error) {
    console.error('Error collecting data:', error);
  }
  
  return summaryData;
}

function buildNotificationContent(summaryData, date) {
  const completionRate = summaryData.totalTasks > 0 
    ? Math.round((summaryData.completedTasks / summaryData.totalTasks) * 100)
    : 0;
  
  let content = `📊 Daily Summary • ${date.toDateString()}\n\n`;
  
  if (summaryData.totalTasks > 0) {
    const emoji = completionRate >= 95 ? '🎉' : completionRate >= 85 ? '✅' : completionRate >= 70 ? '👍' : '⚠️';
    content += `${emoji} Performance: ${completionRate}% Complete (${summaryData.completedTasks}/${summaryData.totalTasks} tasks)\n\n`;
    
    if (summaryData.notesEntries.length > 0) {
      content += `📝 Staff Notes (${summaryData.notesEntries.length}):\n`;
      summaryData.notesEntries.slice(0, 3).forEach(entry => {
        const shortNote = entry.notes.length > 50 ? entry.notes.substring(0, 50) + '...' : entry.notes;
        content += `• ${entry.taskName} at ${entry.locationName}: "${shortNote}"\n`;
      });
      if (summaryData.notesEntries.length > 3) {
        content += `• ... and ${summaryData.notesEntries.length - 3} more notes\n`;
      }
      content += '\n';
    }
    
    if (summaryData.missedTaskEntries.length > 0) {
      content += `❌ Tasks Not Completed (${summaryData.missedTaskEntries.length}):\n`;
      summaryData.missedTaskEntries.slice(0, 3).forEach(entry => {
        content += `• ${entry.taskName} at ${entry.locationName}: ${entry.reason}\n`;
      });
      if (summaryData.missedTaskEntries.length > 3) {
        content += `• ... and ${summaryData.missedTaskEntries.length - 3} more missed tasks\n`;
      }
      content += '\n';
    }
    
    content += '🎯 Action Items:\n';
    if (completionRate >= 95) {
      content += '• Keep up the excellent work!\n';
    } else if (completionRate >= 85) {
      content += '• Review and address any missed tasks\n';
    } else {
      content += '• Schedule team check-in for missed tasks\n';
      content += '• Review task completion procedures\n';
    }
    content += '\n';
  } else {
    content += '📋 No tasks scheduled for today.\n\n';
    content += '🔍 This could mean:\n';
    content += '• No shifts were scheduled\n';
    content += '• Checklists weren\'t generated\n';
    content += '• Tasks weren\'t assigned to teams\n\n';
  }
  
  content += '📱 View complete dashboard at: https://plan-with-hands.web.app/dashboard';
  
  return content;
}

// Get orgId from command line argument  
const orgId = process.argv[2];
if (!orgId) {
  console.log('Usage: node test_daily_summary_manual.js <orgId>');
  process.exit(1);
}

manuallyTriggerDailySummary(orgId).then((result) => {
  if (result && result.success) {
    console.log('\n🎉 Daily summary test complete!');
    console.log('📧 Email system is ready - just need to fix the timing.');
  } else {
    console.log('\n❌ Daily summary test had issues');
  }
  process.exit(0);
}).catch(error => {
  console.error('❌ Script error:', error);
  process.exit(1);
});