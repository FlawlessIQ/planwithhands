const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function diagnoseHamiltonDailySummary() {
  try {
    console.log('=== Daily Summary Diagnostic for Hamilton Organization ===');
    console.log(`Organization: ${ORG_ID}`);
    console.log(`Database: planwithhands\n`);

    // 1. Check organization settings
    console.log('1️⃣ Checking Organization Settings...');
    const orgDoc = await db.collection('organizations').doc(ORG_ID).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }

    const orgData = orgDoc.data();
    console.log(`   Org Name: ${orgData.organizationName || orgData.name || 'Unknown'}`);
    console.log(`   Timezone: ${orgData.timezone || 'Not set (defaults to America/New_York)'}`);
    
    const dailySummarySettings = orgData.dailySummarySettings || {};
    console.log(`   Daily Summary Enabled: ${dailySummarySettings.enabled || false}`);
    console.log(`   Summary Time: ${dailySummarySettings.hour || 17}:${String(dailySummarySettings.minute || 0).padStart(2, '0')}`);
    console.log(`   Summary Period: ${dailySummarySettings.summaryPeriod || 'calendar-day'}\n`);

    // 2. Check recent summary logs
    console.log('2️⃣ Checking Recent Summary Logs...');
    const logsSnapshot = await db
      .collection('organizations')
      .doc(ORG_ID)
      .collection('daily_summary_logs')
      .orderBy('sentAt', 'desc')
      .limit(5)
      .get();

    if (logsSnapshot.empty) {
      console.log('   ⚠️  No summary logs found - summaries may never have been sent\n');
    } else {
      console.log(`   Found ${logsSnapshot.size} recent logs:`);
      logsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const sentAt = data.sentAt?.toDate();
        console.log(`   - ${doc.id}: ${sentAt ? sentAt.toISOString() : 'timestamp missing'}`);
      });
      console.log('');
    }

    // 3. Check yesterday's data
    console.log('3️⃣ Checking Yesterday\'s Task Data (Oct 11, 2025)...');
    const yesterday = '2025-10-11';
    
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(ORG_ID)
      .collection('locations')
      .get();

    console.log(`   Found ${locationsSnapshot.size} locations\n`);

    let totalTasksYesterday = 0;
    let completedTasksYesterday = 0;
    let incompleteTasksYesterday = 0;

    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationName = locationData.locationName || locationDoc.id;
      
      console.log(`   📍 Location: ${locationName}`);

      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(ORG_ID)
        .collection('locations')
        .doc(locationDoc.id)
        .collection('daily_checklists')
        .where('date', '==', yesterday)
        .get();

      console.log(`      Checklists: ${checklistsSnapshot.size}`);

      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        console.log(`      - ${checklistData.templateName || checklistDoc.id}`);

        // Check tasks subcollection
        const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
        
        if (tasksSnapshot.empty) {
          console.log(`        ⚠️  No tasks in subcollection`);
        } else {
          console.log(`        Tasks in subcollection: ${tasksSnapshot.size}`);
          
          let checklistCompleted = 0;
          let checklistIncomplete = 0;

          tasksSnapshot.docs.forEach(taskDoc => {
            const task = taskDoc.data();
            const isCompleted = task.completed || task.isCompleted || false;
            const isCarryForward = task.isCarryForward || false;

            totalTasksYesterday++;
            
            if (isCompleted) {
              completedTasksYesterday++;
              checklistCompleted++;
            } else if (!isCarryForward) {
              // Only count non-carry-forward incomplete tasks
              incompleteTasksYesterday++;
              checklistIncomplete++;
            }
          });

          console.log(`        Completed: ${checklistCompleted}, Incomplete (non-CF): ${checklistIncomplete}`);
        }

        // Also check legacy tasks array (shouldn't be used but let's verify)
        const legacyTasks = checklistData.tasks || [];
        if (legacyTasks.length > 0) {
          console.log(`        ⚠️  LEGACY ARRAY HAS ${legacyTasks.length} TASKS - THIS COULD CAUSE ISSUES`);
        }
      }
      console.log('');
    }

    console.log('📊 SUMMARY FOR YESTERDAY:');
    console.log(`   Total Tasks: ${totalTasksYesterday}`);
    console.log(`   Completed: ${completedTasksYesterday}`);
    console.log(`   Incomplete (non-carry-forward): ${incompleteTasksYesterday}`);
    const percentageYesterday = totalTasksYesterday > 0 
      ? (completedTasksYesterday / totalTasksYesterday * 100).toFixed(1) 
      : 0;
    console.log(`   Completion: ${percentageYesterday}%\n`);

    // 4. Check admin users
    console.log('4️⃣ Checking Admin Users...');
    const usersSnapshot = await db
      .collection('users')
      .where('organizationId', '==', ORG_ID)
      .where('userRole', 'in', [1, 2])
      .where('isActive', '==', true)
      .get();

    if (usersSnapshot.empty) {
      console.log('   ❌ NO ADMIN USERS FOUND - This is why summaries aren\'t being sent!\n');
    } else {
      console.log(`   Found ${usersSnapshot.size} admin users:`);
      usersSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const name = `${data.firstName || ''} ${data.lastName || ''}`.trim();
        console.log(`   - ${name} (${data.email}) - Role: ${data.userRole}`);
      });
      console.log('');
    }

    // 5. Simulate summary generation
    console.log('5️⃣ Simulating Summary Generation Logic...');
    
    if (!dailySummarySettings.enabled) {
      console.log('   ❌ Daily summaries are DISABLED in settings');
      console.log('   → Enable in organization settings to receive summaries\n');
    } else if (usersSnapshot.empty) {
      console.log('   ❌ No admin users to send to');
      console.log('   → Add at least one manager/admin user\n');
    } else if (totalTasksYesterday === 0) {
      console.log('   ⚠️  No tasks found for yesterday');
      console.log('   → Summary would be skipped (no meaningful activity)\n');
    } else {
      console.log('   ✅ All requirements met for sending summary');
      console.log(`   → Would send to ${usersSnapshot.size} admin(s)`);
      console.log(`   → Completion: ${percentageYesterday}%`);
      console.log(`   → Completed: ${completedTasksYesterday}/${totalTasksYesterday}\n`);
    }

    // 6. Diagnosis summary
    console.log('📋 DIAGNOSIS SUMMARY:');
    console.log('═'.repeat(60));
    
    const issues = [];
    const warnings = [];

    if (!dailySummarySettings.enabled) {
      issues.push('Daily summaries are disabled in settings');
    }

    if (usersSnapshot.empty) {
      issues.push('No admin users to receive summaries');
    }

    if (totalTasksYesterday === 0) {
      warnings.push('No task data found for yesterday - check if checklists are being generated');
    }

    if (completedTasksYesterday === 0 && totalTasksYesterday > 0) {
      warnings.push('FOUND ISSUE: 0 completed tasks despite tasks existing');
      warnings.push('This could indicate a data structure problem');
    }

    if (issues.length > 0) {
      console.log('\n❌ CRITICAL ISSUES:');
      issues.forEach(issue => console.log(`   • ${issue}`));
    }

    if (warnings.length > 0) {
      console.log('\n⚠️  WARNINGS:');
      warnings.forEach(warning => console.log(`   • ${warning}`));
    }

    if (issues.length === 0 && warnings.length === 0) {
      console.log('\n✅ No issues detected - summary system should be working');
    }

    console.log('\n' + '═'.repeat(60));

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

diagnoseHamiltonDailySummary();
