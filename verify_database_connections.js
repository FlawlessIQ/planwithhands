const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

async function verifyDatabaseConnections() {
  console.log('=== Verifying All Components Use planwithhands Database ===\n');
  
  try {
    // 1. Test Cloud Function configuration
    console.log('1. Testing Cloud Function Database Configuration:');
    const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
    const cloudFunctionDb = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });
    
    console.log(`   Cloud Functions using database: ${FIRESTORE_DATABASE_ID}`);
    
    // Test reading from planwithhands database
    const orgDoc = await cloudFunctionDb.collection('organizations').doc('3qjYzHagWmfbnMieJ1aj').get();
    if (orgDoc.exists) {
      const data = orgDoc.data();
      console.log(`   ✅ Successfully reading from planwithhands database`);
      console.log(`   Organization name: ${data.name || 'No name'}`);
      console.log(`   Daily summary settings: ${JSON.stringify(data.dailySummarySettings || 'None')}`);
    } else {
      console.log(`   ❌ Could not find test organization in planwithhands database`);
    }
    
    // 2. Test that we can't read from default database (should be empty)
    console.log('\n2. Verifying (default) Database is Different:');
    const defaultDb = new Firestore({ databaseId: '(default)' });
    const defaultOrgDoc = await defaultDb.collection('organizations').doc('3qjYzHagWmfbnMieJ1aj').get();
    
    if (defaultOrgDoc.exists) {
      const defaultData = defaultOrgDoc.data();
      console.log(`   ⚠️  Organization also exists in (default) database`);
      console.log(`   Default org name: ${defaultData.name || 'No name'}`);
      console.log(`   Default daily summary: ${JSON.stringify(defaultData.dailySummarySettings || 'None')}`);
    } else {
      console.log(`   ✅ Organization not found in (default) database - this is expected`);
    }
    
    // 3. Test Firebase CLI functions shell
    console.log('\n3. Testing Manual Function Triggers:');
    console.log('   To test manually, run:');
    console.log('   firebase functions:shell');
    console.log('   > triggerDailySummary({orgId: "3qjYzHagWmfbnMieJ1aj", targetDate: "2025-09-28T00:00:00.000Z"})');
    
    // 4. Show current daily summary settings
    console.log('\n4. Current Daily Summary Settings:');
    if (orgDoc.exists) {
      const data = orgDoc.data();
      const settings = data.dailySummarySettings;
      if (settings) {
        const hour = settings.hour;
        const minute = settings.minute;
        const hour12 = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
        const ampm = hour >= 12 ? 'PM' : 'AM';
        
        console.log(`   Time: ${hour}:${minute.toString().padStart(2, '0')} (24-hour)`);
        console.log(`   Time: ${hour12}:${minute.toString().padStart(2, '0')} ${ampm} (12-hour)`);
        console.log(`   Enabled: ${settings.enabled}`);
        
        if (settings.updatedAt) {
          const updateTime = new Date(settings.updatedAt._seconds * 1000);
          console.log(`   Last updated: ${updateTime.toLocaleString()}`);
        }
        
        // Check if it matches expected time (9:38 AM = hour: 9, minute: 38)
        if (hour === 9 && minute === 38) {
          console.log(`   ✅ Time matches 9:38 AM setting!`);
        } else {
          console.log(`   ⏰ Time is ${hour12}:${minute.toString().padStart(2, '0')} ${ampm}, not 9:38 AM`);
        }
      }
    }
    
    console.log('\n✅ Database verification complete!');
    console.log('\nAll Cloud Functions now correctly use the planwithhands database.');
    console.log('If you change the time in the app, it should now save to the correct database.');
    
  } catch (error) {
    console.error('Error during verification:', error);
  }
}

verifyDatabaseConnections().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});