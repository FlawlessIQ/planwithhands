const admin = require('firebase-admin');
const {DateTime} = require('luxon');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

const CONOR_ORG_ID = '3qjYzHagWmfbnMieJ1aj';

async function diagnoseConorsPubSummary() {
  console.log('\n=== Diagnosing Conor\'s Pub Daily Summary Issue ===\n');
  
  try {
    // Get organization details
    const orgDoc = await db.collection('organizations').doc(CONOR_ORG_ID).get();
    const orgData = orgDoc.data();
    
    console.log('Organization:', orgData.organizationName || orgData.name);
    console.log('Org ID:', CONOR_ORG_ID);
    console.log('Timezone:', orgData.timezone || 'Not set');
    
    const dailySettings = orgData.dailySummarySettings || {};
    console.log('\nDaily Summary Settings:');
    console.log('  Enabled:', dailySettings.enabled);
    console.log('  Time:', `${dailySettings.hour}:${String(dailySettings.minute || 0).padStart(2, '0')}`);
    console.log('  Period:', dailySettings.summaryPeriod || 'calendar-day');
    
    // Calculate when summary should run
    if (dailySettings.enabled) {
      const targetHour = dailySettings.hour;
      const targetMinute = dailySettings.minute || 0;
      const timezone = orgData.timezone || 'America/New_York';
      
      // Convert target time to UTC
      const now = DateTime.now().setZone(timezone);
      const targetTime = now.set({ hour: targetHour, minute: targetMinute, second: 0 });
      const targetUTC = targetTime.toUTC();
      
      console.log('\nSchedule Analysis:');
      console.log(`  Target local time: ${targetTime.toFormat('h:mm a')} ${timezone}`);
      console.log(`  Target UTC time: ${targetUTC.toFormat('HH:mm')} UTC`);
      console.log(`  Function should trigger at: ${targetUTC.hour}:00 UTC`);
    }
    
    // Check recent logs
    console.log('\nRecent Summary Logs:');
    const logsSnapshot = await db
      .collection('organizations')
      .doc(CONOR_ORG_ID)
      .collection('daily_summary_logs')
      .orderBy('sentAt', 'desc')
      .limit(10)
      .get();
    
    if (logsSnapshot.empty) {
      console.log('  No logs found');
    } else {
      logsSnapshot.forEach((doc, index) => {
        const logData = doc.data();
        const sentAt = new Date(logData.sentAt._seconds * 1000);
        console.log(`  ${index + 1}. ${doc.id} - Sent at: ${sentAt.toISOString()}`);
      });
    }
    
    // Check if there are admin users
    console.log('\nAdmin Users:');
    const usersSnapshot = await db
      .collection('users')
      .where('organizationId', '==', CONOR_ORG_ID)
      .get();
    
    const adminUsers = usersSnapshot.docs.filter(doc => {
      const userData = doc.data();
      return userData.userRole >= 1;
    });
    
    console.log(`  Found ${adminUsers.length} admin/manager users (out of ${usersSnapshot.size} total)`);
    adminUsers.forEach(doc => {
      const userData = doc.data();
      console.log(`  - ${userData.name} (${userData.email}) - Role: ${userData.userRole}`);
    });
    
    // Check recent checklist data
    console.log('\nRecent Checklist Data:');
    const yesterday = DateTime.now().setZone(orgData.timezone || 'America/New_York').minus({ days: 1 });
    const yesterdayStr = yesterday.toFormat('yyyy-MM-dd');
    
    console.log(`  Checking for checklists on: ${yesterdayStr}`);
    
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(CONOR_ORG_ID)
      .collection('locations')
      .get();
    
    let totalChecklists = 0;
    let totalTasks = 0;
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationName = locationDoc.data().locationName;
      
      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(CONOR_ORG_ID)
        .collection('locations')
        .doc(locationDoc.id)
        .collection('daily_checklists')
        .where('date', '==', yesterdayStr)
        .get();
      
      console.log(`  Location: ${locationName}`);
      console.log(`    Checklists: ${checklistsSnapshot.size}`);
      
      totalChecklists += checklistsSnapshot.size;
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
        totalTasks += tasksSnapshot.size;
      }
      
      console.log(`    Tasks: ${totalTasks}`);
    }
    
    console.log(`\n  Total: ${totalChecklists} checklists, ${totalTasks} tasks on ${yesterdayStr}`);
    
    if (totalTasks === 0) {
      console.log('\n⚠️  WARNING: No tasks found for yesterday!');
      console.log('   This would cause the summary to be skipped (no meaningful content)');
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

diagnoseConorsPubSummary()
  .then(() => {
    console.log('\nDiagnostic complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('Error:', error);
    process.exit(1);
  });
