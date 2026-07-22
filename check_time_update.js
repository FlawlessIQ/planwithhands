const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the correct database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function checkTimeUpdate() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  console.log('=== Checking for Time Update ===\n');
  
  try {
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (orgDoc.exists) {
      const data = orgDoc.data();
      console.log(`Organization: ${data.name}`);
      console.log(`Timezone: ${data.timezone}`);
      
      const settings = data.dailySummarySettings;
      if (settings) {
        console.log(`\nDaily Summary Settings:`);
        console.log(`  Enabled: ${settings.enabled}`);
        console.log(`  Hour: ${settings.hour}`);
        console.log(`  Minute: ${settings.minute}`);
        console.log(`  Time: ${settings.hour}:${settings.minute.toString().padStart(2, '0')}`);
        
        // Convert to 12-hour format
        const hour12 = settings.hour === 0 ? 12 : settings.hour > 12 ? settings.hour - 12 : settings.hour;
        const ampm = settings.hour >= 12 ? 'PM' : 'AM';
        console.log(`  12-hour format: ${hour12}:${settings.minute.toString().padStart(2, '0')} ${ampm}`);
        
        // Check if it matches 9:50 AM (which would be hour: 9, minute: 50)
        if (settings.hour === 9 && settings.minute === 50) {
          console.log(`\n✅ SUCCESS: Time has been updated to 9:50 AM!`);
        } else {
          console.log(`\n❌ Time has NOT been updated to 9:50 AM yet.`);
          console.log(`   Expected: hour: 9, minute: 50`);
          console.log(`   Current: hour: ${settings.hour}, minute: ${settings.minute}`);
        }
        
        // Show when it was last updated
        if (settings.updatedAt) {
          const updateTime = new Date(settings.updatedAt._seconds * 1000);
          console.log(`\n  Last updated: ${updateTime.toISOString()}`);
          console.log(`  Last updated (local): ${updateTime.toLocaleString()}`);
        }
        
      } else {
        console.log('No daily summary settings found');
      }
      
    } else {
      console.log('Organization not found');
    }
    
  } catch (error) {
    console.error('Error checking time update:', error);
  }
}

checkTimeUpdate().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});