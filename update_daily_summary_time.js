const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com/'
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function updateDailySummaryTime(orgId, hour, minute) {
  try {
    const orgRef = db.collection('organizations').doc(orgId);
    
    await orgRef.update({
      'dailySummarySettings.hour': hour,
      'dailySummarySettings.minute': minute,
      'dailySummarySettings.updatedAt': admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ Updated daily summary time to ${hour}:${String(minute).padStart(2, '0')}`);
    console.log('📧 Daily summaries will now send automatically when the Cloud Function runs!');
    console.log('⏰ Cloud Function runs at 5:00 PM Eastern daily (21:00 UTC)');
    
    // Verify the update
    const orgDoc = await orgRef.get();
    const settings = orgDoc.data().dailySummarySettings;
    console.log('\n🔍 Verified settings:');
    console.log(`   Hour: ${settings.hour}`);
    console.log(`   Minute: ${settings.minute}`);
    console.log(`   Enabled: ${settings.enabled}`);
    console.log(`   Updated: ${settings.updatedAt?.toDate()}`);
    
  } catch (error) {
    console.error('❌ Error updating time:', error);
  }
}

const orgId = process.argv[2];
const hour = parseInt(process.argv[3]);
const minute = parseInt(process.argv[4]);

if (!orgId || isNaN(hour) || isNaN(minute)) {
  console.log('Usage: node update_daily_summary_time.js <orgId> <hour> <minute>');
  console.log('Example: node update_daily_summary_time.js 3qjYzHagWmfbnMieJ1aj 17 0');
  process.exit(1);
}

updateDailySummaryTime(orgId, hour, minute).then(() => {
  process.exit(0);
}).catch(error => {
  console.error('Script error:', error);
  process.exit(1);
});