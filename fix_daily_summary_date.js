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

async function fixDailySummaryDate() {
  try {
    console.log('🔧 Creating manual daily summary for the correct date...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const correctDate = '2025-09-29'; // The date with actual activity
    
    console.log(`Creating daily summary for ${correctDate} (the date with actual activity)`);
    
    // 1. Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    // 2. Get admin users
    const adminUsers = await db.collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', '>=', 2)
      .get();
    
    console.log(`Found ${adminUsers.size} admin users`);
    
    // 3. Create the summary data we calculated earlier
    const summaryData = {
      totalTasks: 617,
      completedTasks: 109,
      completionRate: Math.round(109/617*100),
      checklistsCount: 35, // Total across all locations
      locationsActive: 3,
      date: correctDate,
      organizationName: orgData.name
    };
    
    console.log('Summary data:', summaryData);
    
    // 4. Create notification content
    const title = `Daily Summary - September 29, 2025`;
    const content = `
🏢 ${orgData.name} Daily Summary

📊 Activity Overview:
• ${summaryData.checklistsCount} checklists processed across ${summaryData.locationsActive} locations
• ${summaryData.completedTasks}/${summaryData.totalTasks} tasks completed (${summaryData.completionRate}%)

📍 Location Breakdown:
• The Hamilton Inn: 9 checklists
• Chickies: 11 checklists  
• Hamilton Pork: 15 checklists

✅ Great job on completing ${summaryData.completedTasks} tasks today!

Date: ${correctDate}
Generated: ${new Date().toLocaleString()}
    `.trim();
    
    // 5. Send to each admin user
    for (const userDoc of adminUsers.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      console.log(`\nSending to: ${userData.firstName} ${userData.lastName} (${userData.email})`);
      
      // Check if user has daily summary enabled
      const userNotifRef = db.collection('users').doc(userId).collection('preferences').doc('notifications');
      const userNotifDoc = await userNotifRef.get();
      
      if (userNotifDoc.exists()) {
        const notifData = userNotifDoc.data();
        if (notifData.dailySummaryEnabled) {
          
          // Create in-app notification
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
          
          console.log(`   ✅ Created in-app notification: ${notificationRef.id}`);
          
          // Also create an outbox notification for email
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
              to: userData.email,
              subject: title,
              templateId: 'daily_summary_email',
              templateData: {
                organizationName: orgData.name,
                date: correctDate,
                totalTasks: summaryData.totalTasks,
                completedTasks: summaryData.completedTasks,
                completionRate: summaryData.completionRate,
                checklistsCount: summaryData.checklistsCount
              }
            }
          };
          
          const outboxRef = await db.collection('organizations')
            .doc(orgId)
            .collection('notificationOutbox')
            .add(outboxData);
          
          console.log(`   ✅ Created email outbox: ${outboxRef.id}`);
          
        } else {
          console.log(`   ❌ Daily summary disabled for this user`);
        }
      } else {
        console.log(`   ⚠️  No notification preferences found`);
      }
    }
    
    // 6. Mark daily summary as sent for this date
    const sentLogData = {
      organizationId: orgId,
      date: correctDate,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientCount: adminUsers.size,
      method: 'manual_fix',
      summaryData: summaryData
    };
    
    await db.collection('organizations')
      .doc(orgId)
      .collection('daily_summary_logs')
      .doc(correctDate)
      .set(sentLogData);
    
    console.log(`\n✅ Marked daily summary as sent for ${correctDate}`);
    
    console.log('\n🎉 Manual daily summary created successfully!');
    console.log('\nThis should resolve the immediate issue.');
    console.log('For the long-term fix, the Cloud Function should be updated to:');
    console.log('1. Use the previous day\'s date when sending evening summaries');
    console.log('2. Or be scheduled to run the following morning instead');
    
  } catch (error) {
    console.error('❌ Error creating manual daily summary:', error);
  }
}

fixDailySummaryDate();