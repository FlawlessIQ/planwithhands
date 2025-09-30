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

async function addOrgNotificationPreferences() {
  try {
    console.log('🔧 Adding notification preferences to Hamilton Pork organization...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // Get current organization data
    const orgRef = db.collection('organizations').doc(orgId);
    const orgDoc = await orgRef.get();
    const orgData = orgDoc.data();
    
    console.log(`Current organization: ${orgData.name}`);
    console.log(`Timezone: ${orgData.timezone}`);
    
    // Based on John's user preference (20:00), set organization daily summary time
    // John has it set to 8 PM, so let's set the org-wide setting to 8 PM as well
    const dailySummarySettings = {
      enabled: true,
      hour: 20,      // 8 PM
      minute: 0      // On the hour
    };
    
    console.log('\nAdding daily summary settings:');
    console.log(`   Enabled: ${dailySummarySettings.enabled}`);
    console.log(`   Time: ${dailySummarySettings.hour}:${dailySummarySettings.minute.toString().padStart(2, '0')}`);
    console.log(`   Timezone: ${orgData.timezone} (America/New_York)`);
    
    // Update the organization with the missing daily summary settings
    await orgRef.update({
      dailySummarySettings: dailySummarySettings,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('\n✅ Successfully added daily summary settings to Hamilton Pork');
    
    // Also check if we need to add any notification preferences structure
    // Based on the investigation, we might also need notification preferences
    const notificationPreferences = {
      emailNotifications: {
        dailySummary: {
          enabled: true,
          recipients: ['admin'],  // Send to admin users
          template: 'daily_summary_email'
        }
      },
      pushNotifications: {
        dailySummary: {
          enabled: true,
          recipients: ['admin']
        }
      }
    };
    
    console.log('\nAdding notification preferences structure:');
    console.log(JSON.stringify(notificationPreferences, null, 2));
    
    await orgRef.update({
      notificationPreferences: notificationPreferences,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('\n✅ Successfully added notification preferences to Hamilton Pork');
    
    // Verify the update
    console.log('\n🔍 Verifying the updates...');
    const updatedOrgDoc = await orgRef.get();
    const updatedOrgData = updatedOrgDoc.data();
    
    if (updatedOrgData.dailySummarySettings) {
      console.log('✅ Daily summary settings confirmed:');
      console.log(`   Enabled: ${updatedOrgData.dailySummarySettings.enabled}`);
      console.log(`   Time: ${updatedOrgData.dailySummarySettings.hour}:${updatedOrgData.dailySummarySettings.minute}`);
    }
    
    if (updatedOrgData.notificationPreferences) {
      console.log('✅ Notification preferences confirmed');
    }
    
    console.log('\n📋 NEXT STEPS:');
    console.log('==============');
    console.log('1. Daily summary should now be enabled for Hamilton Pork');
    console.log('2. It will run at 8:00 PM EST (America/New_York timezone)');
    console.log('3. Admin users (like John Gondevas) should receive email notifications');
    console.log('4. The scheduled function should pick this up on the next hourly run');
    console.log('5. Monitor logs to ensure the function executes successfully');
    
  } catch (error) {
    console.error('❌ Error adding notification preferences:', error);
  }
}

addOrgNotificationPreferences();