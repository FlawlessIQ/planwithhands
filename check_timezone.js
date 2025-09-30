const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project ID
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function checkTimezoneConversion() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  console.log('=== Timezone Analysis ===\n');
  
  try {
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    const settings = orgData.dailySummarySettings;
    const timezone = orgData.timezone;
    
    console.log(`Organization timezone: ${timezone}`);
    console.log(`Daily summary time: ${settings.hour}:${settings.minute.toString().padStart(2, '0')}`);
    
    // Convert to different timezones
    const baseTime = new Date();
    baseTime.setHours(settings.hour, settings.minute, 0, 0);
    
    console.log(`\nTime conversions for ${settings.hour}:${settings.minute.toString().padStart(2, '0')}:`);
    console.log(`- Eastern Time (${timezone}): ${settings.hour}:${settings.minute.toString().padStart(2, '0')}`);
    
    // Check if 15:20 (3:20 PM) matches when converted
    if (settings.hour === 15 && settings.minute === 20) {
      console.log('✅ This matches 3:20 PM!');
    } else {
      console.log(`❌ This is ${settings.hour}:${settings.minute.toString().padStart(2, '0')}, not 3:20 PM`);
      
      // Let's see what time would give us 3:20 PM
      console.log('\nIf the app shows 3:20 PM, the database should show:');
      console.log('- Hour: 15, Minute: 20 (for 3:20 PM in 24-hour format)');
    }
    
    // Let's check if there are any other organizations with time 15:20
    console.log('\n=== Checking for orgs with 15:20 time ===');
    const allOrgs = await db.collection('organizations').get();
    let found = false;
    
    allOrgs.docs.forEach(doc => {
      const data = doc.data();
      if (data.dailySummarySettings && data.dailySummarySettings.hour === 15 && data.dailySummarySettings.minute === 20) {
        console.log(`Found org ${doc.id} with 15:20 time setting`);
        found = true;
      }
    });
    
    if (!found) {
      console.log('No organizations found with 15:20 (3:20 PM) time setting');
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

checkTimezoneConversion().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});