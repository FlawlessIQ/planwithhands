// Manually trigger daily summaries for organizations with data
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

// Use the correct database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function triggerDailySummaries() {
  console.log('🚀 Manually triggering daily summaries...');
  
  try {
    // Organizations with actual checklist activity
    const activeOrgs = [
      { id: 'vnE0olvi1Tswjtdb19MI', name: 'Flawless Pubs' },
      { id: 'FErQ4pkcrCovJ7T6L13M', name: 'Hamilton Pork' }
    ];
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split('T')[0];
    
    for (const org of activeOrgs) {
      console.log(`\n📋 Creating daily summary for ${org.name}...`);
      
      // Get admin users for this org
      const adminQuery = await db
        .collection('users')
        .where('organizationId', '==', org.id)
        .where('userRole', 'in', [1, 2])
        .where('isActive', '==', true)
        .get();
      
      if (adminQuery.docs.length === 0) {
        console.log(`   ⚠️ No admin users found for ${org.name}`);
        continue;
      }
      
      console.log(`   Found ${adminQuery.docs.length} admin users`);
      
      // Create summary notifications for each admin
      const batch = db.batch();
      const timestamp = admin.firestore.FieldValue.serverTimestamp();
      
      for (const adminDoc of adminQuery.docs) {
        const adminData = adminDoc.data();
        const notificationRef = db
          .collection('organizations')
          .doc(org.id)
          .collection('notifications')
          .doc();
        
        const notificationData = {
          title: `Daily Notes Summary - ${yesterday.toLocaleDateString('en-US', { 
            weekday: 'long', 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric' 
          })}`,
          message: `📊 Daily Summary Report for ${org.name}\n\nThis is a test summary to verify the notification system is working.\n\nPlease check the app for detailed task completion data.`,
          userId: adminDoc.id,
          type: 'general',
          createdAt: timestamp,
          readBy: [],
          archivedBy: [],
          targetType: 'user',
          targetId: adminDoc.id,
          targets: {
            userRole: [1, 2],
            userId: [adminDoc.id]
          },
          // Set expiration to 30 days from now
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
        };
        
        batch.set(notificationRef, notificationData);
        console.log(`   📬 Queued notification for ${adminData.firstName} ${adminData.lastName}`);
      }
      
      await batch.commit();
      console.log(`   ✅ Daily summary notifications created for ${org.name}`);
      
      // Mark as sent in daily summary logs
      const logRef = db
        .collection('organizations')
        .doc(org.id)
        .collection('daily_summary_logs')
        .doc(yesterdayStr);
      
      await logRef.set({
        date: yesterdayStr,
        sentAt: timestamp,
        organizationId: org.id,
        manualTrigger: true,
        // Set expiration to 90 days from now
        expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)
      });
      
      console.log(`   📝 Marked as sent in daily summary logs`);
    }
    
    console.log('\n🎉 Daily summaries triggered successfully!');
    console.log('\nWhat should happen next:');
    console.log('1. Check Firebase Console > Functions > Logs for onDailySummaryNotificationCreated triggers');
    console.log('2. Admin users should receive push notifications');
    console.log('3. Check the notifications page in the app');
    
  } catch (error) {
    console.error('❌ Error triggering daily summaries:', error);
  }
  
  process.exit(0);
}

triggerDailySummaries();
