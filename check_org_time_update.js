const admin = require('firebase-admin');

// Initialize Firebase Admin with the correct database
const app = admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com/',
}, 'check-org-time');

// Use the 'planwithhands' database
const db = new admin.firestore.Firestore({
  projectId: 'plan-with-hands',
  databaseId: 'planwithhands'
});

async function checkOrgTimeUpdate() {
  try {
    console.log('🔍 Checking organization daily summary settings...');
    
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      const dailySummarySettings = orgData.dailySummarySettings;
      
      console.log('📊 Organization daily summary settings:');
      console.log('   - Hour:', dailySummarySettings?.hour);
      console.log('   - Minute:', dailySummarySettings?.minute);
      console.log('   - Enabled:', dailySummarySettings?.enabled);
      console.log('   - Last Updated:', dailySummarySettings?.updatedAt?.toDate?.() || dailySummarySettings?.updatedAt);
      
      const timeString = `${dailySummarySettings?.hour || 0}:${(dailySummarySettings?.minute || 0).toString().padStart(2, '0')}`;
      console.log('   - Time Display:', timeString);
      
      // Check if this matches 9:50 AM
      if (dailySummarySettings?.hour === 9 && dailySummarySettings?.minute === 50) {
        console.log('✅ SUCCESS: Organization settings show 9:50 AM!');
      } else {
        console.log('⚠️  Still showing old time, not 9:50 AM');
      }
    } else {
      console.log('❌ Organization document not found');
    }
    
  } catch (error) {
    console.error('❌ Error checking organization settings:', error);
  } finally {
    process.exit(0);
  }
}

checkOrgTimeUpdate();