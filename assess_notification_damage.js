const admin = require('firebase-admin');

// Initialize Firebase Admin using default credentials
// This will use the same project as your functions
if (!admin.apps.length) {
  admin.initializeApp();
}

// Use the planwithhands database
const db = admin.firestore();
const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function assessNotificationDamage() {
  console.log('🔍 ASSESSING NOTIFICATION DAMAGE');
  console.log('================================\n');

  try {
    // Get all organizations to check their notifications
    const orgsSnapshot = await planWithHandsDb.collection('organizations').get();
    console.log(`📊 Found ${orgsSnapshot.size} organizations\n`);

    let totalNotifications = 0;
    let recentNotifications = 0;
    let duplicatesByTitle = {};
    let notificationsByOrg = {};

    // Check each organization's notifications
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      console.log(`\n🏢 Organization: ${orgData.organizationName || orgId}`);
      
      // Get notifications for this org
      const notificationsSnapshot = await planWithHandsDb
        .collection('organizations')
        .doc(orgId)
        .collection('notifications')
        .orderBy('createdAt', 'desc')
        .get();

      const orgNotificationCount = notificationsSnapshot.size;
      totalNotifications += orgNotificationCount;
      notificationsByOrg[orgId] = {
        name: orgData.organizationName || orgId,
        count: orgNotificationCount,
        notifications: []
      };

      console.log(`   📋 Total notifications: ${orgNotificationCount}`);

      // Analyze recent notifications (last 2 hours)
      const twoHoursAgo = new Date(Date.now() - (2 * 60 * 60 * 1000));
      
      notificationsSnapshot.docs.forEach(doc => {
        const notification = doc.data();
        const createdAt = notification.createdAt?.toDate();
        
        notificationsByOrg[orgId].notifications.push({
          id: doc.id,
          title: notification.title,
          message: notification.message,
          createdAt: createdAt,
          userId: notification.userId,
          targetType: notification.targetType
        });

        // Count recent notifications
        if (createdAt && createdAt > twoHoursAgo) {
          recentNotifications++;
        }

        // Track duplicates by title
        const titleKey = notification.title || 'No Title';
        if (!duplicatesByTitle[titleKey]) {
          duplicatesByTitle[titleKey] = 0;
        }
        duplicatesByTitle[titleKey]++;
      });

      // Show recent activity for this org
      const recentForOrg = notificationsByOrg[orgId].notifications.filter(n => 
        n.createdAt && n.createdAt > twoHoursAgo
      ).length;
      
      if (recentForOrg > 0) {
        console.log(`   🚨 Recent notifications (last 2h): ${recentForOrg}`);
      }
    }

    console.log('\n📈 DAMAGE SUMMARY');
    console.log('==================');
    console.log(`Total notifications across all orgs: ${totalNotifications}`);
    console.log(`Recent notifications (last 2h): ${recentNotifications}`);
    
    console.log('\n📊 NOTIFICATIONS BY ORGANIZATION');
    console.log('=================================');
    Object.entries(notificationsByOrg).forEach(([orgId, data]) => {
      console.log(`${data.name}: ${data.count} notifications`);
    });

    console.log('\n🔄 DUPLICATE ANALYSIS BY TITLE');
    console.log('===============================');
    const sortedDuplicates = Object.entries(duplicatesByTitle)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 10); // Top 10 most duplicated

    sortedDuplicates.forEach(([title, count]) => {
      if (count > 1) {
        console.log(`"${title}": ${count} copies`);
      }
    });

    // Find the most recent problematic notifications
    console.log('\n🕐 TIMELINE OF RECENT ACTIVITY');
    console.log('==============================');
    
    const allRecentNotifications = [];
    Object.values(notificationsByOrg).forEach(orgData => {
      orgData.notifications.forEach(notif => {
        if (notif.createdAt && notif.createdAt > twoHoursAgo) {
          allRecentNotifications.push({
            ...notif,
            orgName: orgData.name
          });
        }
      });
    });

    // Sort by creation time
    allRecentNotifications.sort((a, b) => a.createdAt - b.createdAt);
    
    // Show sample of recent notifications
    console.log('Sample of recent notifications:');
    allRecentNotifications.slice(0, 20).forEach(notif => {
      const timeStr = notif.createdAt.toLocaleTimeString();
      console.log(`${timeStr} - ${notif.orgName}: "${notif.title}" (${notif.targetType || 'unknown target'})`);
    });

    if (allRecentNotifications.length > 20) {
      console.log(`... and ${allRecentNotifications.length - 20} more recent notifications`);
    }

    console.log('\n💾 DATA INTEGRITY CHECK');
    console.log('========================');
    
    // Check if there are any original notifications that should be preserved
    const originalNotifications = [];
    Object.values(notificationsByOrg).forEach(orgData => {
      orgData.notifications.forEach(notif => {
        if (notif.createdAt && notif.createdAt < twoHoursAgo) {
          originalNotifications.push(notif);
        }
      });
    });

    console.log(`Original notifications (older than 2h): ${originalNotifications.length}`);
    console.log(`Potentially problematic notifications: ${recentNotifications}`);

    if (recentNotifications > 1000) {
      console.log('\n⚠️  WARNING: High volume of recent notifications detected!');
      console.log('This suggests the infinite loop created significant duplicates.');
    }

    return {
      totalNotifications,
      recentNotifications,
      duplicatesByTitle,
      notificationsByOrg,
      originalNotifications: originalNotifications.length
    };

  } catch (error) {
    console.error('Error assessing damage:', error);
    throw error;
  }
}

// Run the assessment
assessNotificationDamage()
  .then((results) => {
    console.log('\n✅ Assessment complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Assessment failed:', error);
    process.exit(1);
  });
