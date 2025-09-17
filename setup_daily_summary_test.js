const admin = require('firebase-admin');

// Initialize Firebase Admin with your service account
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const firestore = admin.firestore();

async function testDailySummaryWithExistingData() {
  console.log('🧪 Testing Daily Summary with existing data...\n');

  try {
    // Let's test with the organization that has tasks: 'cf-org' or 'multi-org'
    const testOrgId = 'multi-org'; // This org has multiple tasks
    
    console.log(`🎯 Testing with organization: ${testOrgId}\n`);

    // 1. Create a test admin user for this organization if none exists
    console.log('1. Setting up test admin user...');
    
    const testUserId = 'test-admin-user-12345';
    const testUserRef = firestore.collection('users').doc(testUserId);
    
    await testUserRef.set({
      email: 'admin@example.com',
      displayName: 'Test Admin',
      role: 'admin',
      organizationId: testOrgId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      fcmToken: 'test-fcm-token-12345' // Required for notifications
    });
    
    console.log(`✅ Created test admin user: ${testUserId}`);

    // 2. Check tasks for this organization
    console.log('\n2. Checking tasks for this organization...');
    const tasksSnapshot = await firestore
      .collectionGroup('tasks')
      .where('organizationId', '==', testOrgId)
      .get();

    console.log(`✅ Found ${tasksSnapshot.size} tasks for ${testOrgId}:`);
    tasksSnapshot.forEach(taskDoc => {
      const taskData = taskDoc.data();
      console.log(`   - ${taskDoc.id}: ${taskData.title || 'Untitled'}`);
      console.log(`     Status: ${taskData.status || 'None'}`);
      console.log(`     Due: ${taskData.dueDate?.toDate() || 'No date'}`);
    });

    // 3. Update some tasks to have yesterday's date and different statuses
    console.log('\n3. Setting up test data with yesterday\'s date...');
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(12, 0, 0, 0); // Set to noon yesterday

    const taskDocs = tasksSnapshot.docs.slice(0, 3); // Use first 3 tasks
    
    if (taskDocs.length >= 2) {
      // Mark first task as completed
      await taskDocs[0].ref.update({
        status: 'completed',
        dueDate: admin.firestore.Timestamp.fromDate(yesterday),
        completedAt: admin.firestore.Timestamp.fromDate(yesterday),
        title: 'Completed Task'
      });
      console.log(`   ✅ Set task ${taskDocs[0].id} as completed yesterday`);

      // Mark second task as missed (overdue)
      await taskDocs[1].ref.update({
        status: 'pending', // Still pending but overdue
        dueDate: admin.firestore.Timestamp.fromDate(yesterday),
        title: 'Missed Task'
      });
      console.log(`   ⏰ Set task ${taskDocs[1].id} as missed (overdue) yesterday`);
    }

    // 4. Test the Cloud Function manually by calling it directly
    console.log('\n4. Testing triggerDailySummary Cloud Function...');
    
    // We'll use the Firebase Functions SDK to test
    const testPayload = {
      organizationId: testOrgId,
      targetDate: yesterday.toISOString()
    };

    console.log('🚀 Test payload:', testPayload);
    console.log('📞 In a real test, this would call the triggerDailySummary function');

    // 5. Simulate what the function would do
    console.log('\n5. Simulating daily summary generation...');
    
    // Create a summary log entry
    const dateStr = yesterday.toISOString().split('T')[0];
    const summaryLogRef = firestore
      .collection('organizations')
      .doc(testOrgId)
      .collection('daily_summary_logs')
      .doc(dateStr);

    await summaryLogRef.set({
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      sentToUserIds: [testUserId],
      organizationId: testOrgId,
      summaryDate: admin.firestore.Timestamp.fromDate(yesterday),
      tasksCompleted: 1,
      tasksMissed: 1,
      totalTasks: 2,
      testRun: true
    });

    console.log(`✅ Created summary log for ${dateStr}`);

    // 6. Create a test notification for the admin
    console.log('\n6. Creating test notification...');
    
    const notificationData = {
      type: 'daily_summary',
      title: 'Daily Summary - Test',
      body: `Yesterday: 1 task completed, 1 task missed out of 2 total tasks`,
      organizationId: testOrgId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      data: {
        summaryDate: dateStr,
        tasksCompleted: 1,
        tasksMissed: 1,
        totalTasks: 2
      }
    };

    // Using the outbox pattern for reliable delivery
    const outboxRef = firestore.collection('notificationOutbox').doc();
    await outboxRef.set({
      userId: testUserId,
      notificationData: notificationData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
      attempts: 0
    });

    console.log(`✅ Created outbox notification for user ${testUserId}`);

    // Also create direct notification
    const userNotificationRef = firestore
      .collection('userNotifications')
      .doc(testUserId)
      .collection('notifications')
      .doc();

    await userNotificationRef.set(notificationData);
    console.log(`✅ Created direct notification for user ${testUserId}`);

    // 7. Verify the setup
    console.log('\n7. Verifying test setup...');
    
    const logDoc = await summaryLogRef.get();
    if (logDoc.exists) {
      console.log(`✅ Summary log created successfully`);
      const logData = logDoc.data();
      console.log(`   - Date: ${dateStr}`);
      console.log(`   - Tasks completed: ${logData.tasksCompleted}`);
      console.log(`   - Tasks missed: ${logData.tasksMissed}`);
      console.log(`   - Recipients: ${logData.sentToUserIds?.length || 0}`);
    }

    const notificationCheck = await firestore
      .collection('userNotifications')
      .doc(testUserId)
      .collection('notifications')
      .where('type', '==', 'daily_summary')
      .get();

    console.log(`✅ User has ${notificationCheck.size} daily summary notifications`);

    console.log('\n✅ Daily Summary Test Setup Complete!');
    console.log('\n📋 What was created:');
    console.log(`   - Test admin user: ${testUserId}`);
    console.log(`   - Organization: ${testOrgId}`);
    console.log(`   - Tasks with yesterday's date (completed and missed)`);
    console.log(`   - Daily summary log entry`);
    console.log(`   - Test notifications in outbox and user collections`);
    
    console.log('\n🔥 The system is now ready for testing!');
    console.log('💡 You can use the debug widget in the Flutter app to test with real Cloud Functions.');
    console.log(`🎯 Test organization ID: ${testOrgId}`);
    console.log(`👤 Test admin user ID: ${testUserId}`);

  } catch (error) {
    console.error('❌ Error setting up daily summary test:', error);
  }
}

// Run the test setup
testDailySummaryWithExistingData().then(() => {
  console.log('\n🏁 Test setup completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Test setup failed:', error);
  process.exit(1);
});