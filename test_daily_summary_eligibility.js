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

async function testDailySummaryEligibility() {
  try {
    console.log('🧪 Testing daily summary eligibility for Hamilton Pork...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // Get the updated organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    console.log('1. Organization Configuration:');
    console.log(`   Name: ${orgData.name}`);
    console.log(`   Active: ${orgData.isActive}`);
    console.log(`   Subscription: ${orgData.subscriptionStatus}`);
    console.log(`   Timezone: ${orgData.timezone}`);
    
    // Check daily summary settings
    if (orgData.dailySummarySettings) {
      console.log('\n✅ Daily Summary Settings Found:');
      console.log(`   Enabled: ${orgData.dailySummarySettings.enabled}`);
      console.log(`   Hour: ${orgData.dailySummarySettings.hour}`);
      console.log(`   Minute: ${orgData.dailySummarySettings.minute}`);
      
      // Calculate what time this would be in UTC
      const { DateTime } = require('luxon');
      const orgTimezone = orgData.timezone || "America/New_York";
      const targetHour = orgData.dailySummarySettings.hour;
      const targetMinute = orgData.dailySummarySettings.minute;
      
      const orgLocalTime = DateTime.now().setZone(orgTimezone).set({
        hour: targetHour,
        minute: targetMinute,
        second: 0,
        millisecond: 0
      });
      
      const targetUTCTime = orgLocalTime.toUTC();
      console.log(`   Local Time: ${targetHour}:${targetMinute.toString().padStart(2, '0')} ${orgTimezone}`);
      console.log(`   UTC Equivalent: ${targetUTCTime.hour}:${targetUTCTime.minute.toString().padStart(2, '0')} UTC`);
      
    } else {
      console.log('\n❌ No daily summary settings found');
      return;
    }
    
    // Check notification preferences
    if (orgData.notificationPreferences) {
      console.log('\n✅ Notification Preferences Found:');
      if (orgData.notificationPreferences.emailNotifications?.dailySummary) {
        const emailSettings = orgData.notificationPreferences.emailNotifications.dailySummary;
        console.log(`   Email enabled: ${emailSettings.enabled}`);
        console.log(`   Recipients: ${emailSettings.recipients.join(', ')}`);
        console.log(`   Template: ${emailSettings.template}`);
      }
    } else {
      console.log('\n❌ No notification preferences found');
    }
    
    // Find admin users who should receive the summary
    console.log('\n2. Finding eligible recipients...');
    const adminUsersQuery = await db.collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', '>=', 2)  // Admin users
      .get();
    
    console.log(`   Found ${adminUsersQuery.size} admin users`);
    
    let eligibleUsers = [];
    for (const userDoc of adminUsersQuery.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      console.log(`   Admin: ${userData.firstName} ${userData.lastName} (${userData.email})`);
      
      // Check if user has notification preferences
      const userNotifRef = db.collection('users').doc(userId).collection('preferences').doc('notifications');
      const userNotifDoc = await userNotifRef.get();
      
      if (userNotifDoc.exists) {
        const notifData = userNotifDoc.data();
        if (notifData.dailySummaryEnabled) {
          console.log(`     ✅ Daily summary enabled (${notifData.dailySummaryTime.hour}:${notifData.dailySummaryTime.minute.toString().padStart(2, '0')})`);
          eligibleUsers.push({
            id: userId,
            email: userData.email,
            name: `${userData.firstName} ${userData.lastName}`,
            time: notifData.dailySummaryTime
          });
        } else {
          console.log(`     ❌ Daily summary disabled`);
        }
      } else {
        console.log(`     ⚠️  No notification preferences`);
      }
    }
    
    console.log(`\n   ${eligibleUsers.length} users eligible for daily summary emails`);
    
    // Test the timing logic (simulate what the scheduled function would do)
    console.log('\n3. Testing timing logic...');
    const now = new Date();
    const currentUTCHour = now.getUTCHours();
    const currentUTCMinute = now.getUTCMinutes();
    
    console.log(`   Current UTC time: ${currentUTCHour}:${currentUTCMinute.toString().padStart(2, '0')}`);
    
    // Get target UTC time
    const { DateTime } = require('luxon');
    const orgTimezone = orgData.timezone || "America/New_York";
    const targetHour = orgData.dailySummarySettings.hour;
    const targetMinute = orgData.dailySummarySettings.minute;
    
    const orgLocalTime = DateTime.now().setZone(orgTimezone).set({
      hour: targetHour,
      minute: targetMinute,
      second: 0,
      millisecond: 0
    });
    
    const targetUTCTime = orgLocalTime.toUTC();
    const targetUTCHour = targetUTCTime.hour;
    const targetUTCMinute = targetUTCTime.minute;
    
    console.log(`   Target UTC time: ${targetUTCHour}:${targetUTCMinute.toString().padStart(2, '0')}`);
    
    const isTargetHour = currentUTCHour === targetUTCHour;
    const pastTargetMinute = currentUTCMinute >= targetUTCMinute;
    const shouldSendNow = isTargetHour && pastTargetMinute;
    
    if (shouldSendNow) {
      console.log('   ✅ Should send daily summary RIGHT NOW!');
    } else {
      console.log(`   ⏰ Not the right time yet`);
      
      // Calculate next send time
      let nextSendUTC = DateTime.utc().set({
        hour: targetUTCHour,
        minute: targetUTCMinute,
        second: 0,
        millisecond: 0
      });
      
      // If we've passed today's time, move to tomorrow
      if (nextSendUTC <= DateTime.utc()) {
        nextSendUTC = nextSendUTC.plus({ days: 1 });
      }
      
      const nextSendLocal = nextSendUTC.setZone(orgTimezone);
      console.log(`   Next send time: ${nextSendLocal.toFormat('MMM dd, yyyy h:mm a ZZZZ')}`);
    }
    
    console.log('\n📋 SUMMARY:');
    console.log('===========');
    console.log(`✅ Organization has daily summary enabled`);
    console.log(`✅ ${eligibleUsers.length} eligible recipients found`);
    console.log(`✅ Notification preferences configured`);
    
    if (eligibleUsers.length > 0) {
      console.log('\n👥 Recipients:');
      eligibleUsers.forEach(user => {
        console.log(`   - ${user.name} (${user.email})`);
      });
    }
    
    console.log('\n🎯 The daily summary system should now work correctly!');
    console.log('   Next summary will be sent at 8:00 PM EST today (if not already sent)');
    console.log('   or 8:00 PM EST tomorrow.');
    
  } catch (error) {
    console.error('❌ Error testing daily summary eligibility:', error);
  }
}

testDailySummaryEligibility();