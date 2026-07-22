const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
// Use the correct Firestore database (not the default)
db.settings({ databaseId: 'planwithhands' });

async function sendDailySummaryToJohn() {
  try {
    console.log('📧 Sending daily summary directly to John Gondevas...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const userId = 'sXAEgtodreSTrXU0DUpHKEoq0LC3'; // John's user ID
    const userEmail = 'jgondevas@gmail.com';
    const correctDate = '2025-09-29'; // The date with actual activity
    
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    console.log(`Organization: ${orgData.name}`);
    console.log(`Sending to: ${userEmail}`);
    console.log(`Date: ${correctDate}`);
    
    // Create summary content based on our analysis
    const title = `Daily Summary - September 29, 2025`;
    const content = `
🏢 ${orgData.name} Daily Summary

📊 Activity Overview:
• 35 checklists processed across 3 locations
• 109/617 tasks completed (18%)

📍 Location Breakdown:
• The Hamilton Inn: 9 checklists with some tasks completed
• Chickies: 11 checklists with good progress
• Hamilton Pork: 15 checklists with solid completion rates

✅ Great job on completing 109 tasks today!

This summary covers activity from ${correctDate}.
Generated: ${new Date().toLocaleString()} EST
    `.trim();
    
    console.log('\nSummary content:');
    console.log(content);
    
    // 1. Create in-app notification
    console.log('\n📱 Creating in-app notification...');
    const notificationData = {
      userId: userId,
      organizationId: orgId,
      type: 'daily_summary',
      title: title,
      content: content,
      date: correctDate,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      archived: false
    };
    
    const notificationRef = await db.collection('organizations')
      .doc(orgId)
      .collection('notifications')
      .add(notificationData);
    
    console.log(`✅ Created in-app notification: ${notificationRef.id}`);
    
    // 2. Create email outbox notification
    console.log('\n📧 Creating email notification...');
    const outboxData = {
      organizationId: orgId,
      type: 'daily_summary',
      targetType: 'user',
      targetId: userId,
      title: title,
      content: content,
      date: correctDate,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      emailData: {
        to: userEmail,
        subject: title,
        templateId: 'daily_summary_email',
        templateData: {
          organizationName: orgData.name,
          date: correctDate,
          totalTasks: 617,
          completedTasks: 109,
          completionRate: 18,
          checklistsCount: 35,
          locationBreakdown: [
            { name: 'The Hamilton Inn', checklists: 9 },
            { name: 'Chickies', checklists: 11 },
            { name: 'Hamilton Pork', checklists: 15 }
          ]
        }
      }
    };
    
    const outboxRef = await db.collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add(outboxData);
    
    console.log(`✅ Created email outbox: ${outboxRef.id}`);
    
    // 3. Mark daily summary as sent
    console.log('\n📝 Marking daily summary as sent...');
    const sentLogData = {
      organizationId: orgId,
      date: correctDate,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientCount: 1,
      method: 'manual_fix_for_john',
      summaryData: {
        totalTasks: 617,
        completedTasks: 109,
        completionRate: 18,
        checklistsCount: 35,
        locationsActive: 3
      },
      recipients: [userId]
    };
    
    await db.collection('organizations')
      .doc(orgId)
      .collection('daily_summary_logs')
      .doc(`${correctDate}-manual`)
      .set(sentLogData);
    
    console.log(`✅ Marked daily summary as sent for ${correctDate}`);
    
    console.log('\n🎉 Daily summary sent successfully!');
    console.log('\n📱 John should now see:');
    console.log('   1. In-app notification in the Hamilton Pork app');
    console.log('   2. Email notification at jgondevas@gmail.com');
    console.log('\n🔍 To verify:');
    console.log('   1. Check Firebase Console for the created documents');
    console.log('   2. Check Cloud Function logs for email processing');
    console.log('   3. Ask John to check his email and app notifications');
    
    // 4. Also create activity for today so future runs work
    console.log('\n🔧 The test daily checklist for today (2025-09-30) was already created.');
    console.log('   The next hourly function run should send tomorrow\'s summary automatically.');
    
  } catch (error) {
    console.error('❌ Error sending daily summary to John:', error);
  }
}

sendDailySummaryToJohn();