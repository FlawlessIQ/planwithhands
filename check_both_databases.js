const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

async function checkBothDatabases() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  console.log('=== Checking Both Databases for Time Update ===\n');
  
  try {
    // Check planwithhands database
    console.log('1. Checking planwithhands database:');
    const dbPlan = new Firestore({ databaseId: 'planwithhands' });
    const orgDocPlan = await dbPlan.collection('organizations').doc(orgId).get();
    
    if (orgDocPlan.exists) {
      const data = orgDocPlan.data();
      const settings = data.dailySummarySettings;
      console.log(`   Name: ${data.name}`);
      console.log(`   Time: ${settings.hour}:${settings.minute.toString().padStart(2, '0')} (${settings.hour === 9 && settings.minute === 38 ? '✅ 9:38 AM!' : '❌ not 9:38 AM'})`);
      if (settings.updatedAt) {
        const updateTime = new Date(settings.updatedAt._seconds * 1000);
        console.log(`   Updated: ${updateTime.toLocaleString()}`);
      }
    } else {
      console.log('   ❌ Not found in planwithhands');
    }
    
    // Check default database
    console.log('\n2. Checking (default) database:');
    const dbDefault = new Firestore({ databaseId: '(default)' });
    const orgDocDefault = await dbDefault.collection('organizations').doc(orgId).get();
    
    if (orgDocDefault.exists) {
      const data = orgDocDefault.data();
      const settings = data.dailySummarySettings;
      console.log(`   Name: ${data.name || 'No name'}`);
      if (settings) {
        console.log(`   Time: ${settings.hour}:${settings.minute.toString().padStart(2, '0')} (${settings.hour === 9 && settings.minute === 38 ? '✅ 9:38 AM!' : '❌ not 9:38 AM'})`);
        if (settings.updatedAt) {
          const updateTime = new Date(settings.updatedAt._seconds * 1000);
          console.log(`   Updated: ${updateTime.toLocaleString()}`);
        }
      } else {
        console.log('   No daily summary settings');
      }
    } else {
      console.log('   ❌ Not found in (default)');
    }
    
    console.log('\n=== Recommendation ===');
    console.log('If the app shows 9:38 AM but neither database has it:');
    console.log('1. Check if the app is connected to the correct Firebase project');
    console.log('2. Check if there are any save errors in the app console');
    console.log('3. Try refreshing the app and making the change again');
    
  } catch (error) {
    console.error('Error checking databases:', error);
  }
}

checkBothDatabases().then(() => {
  console.log('\nDone.');
  process.exit(0);
}).catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});