const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

async function checkUsersAndTokens() {
  try {
    console.log('👥 Checking users and tokens in organization...');
    
    const orgId = 'II9B1k7dQcHpzDoU1e9C'; // From the logs
    
    // Connect to the correct database
    const db = admin.app().firestore('planwithhands');
    
    // Check users in the organization
    console.log('🔍 Looking for users in organization:', orgId);
    const usersSnapshot = await db.collection('users')
      .where('organizationId', '==', orgId)
      .where('isActive', '==', true)
      .get();
    
    console.log(`📊 Found ${usersSnapshot.docs.length} active users in the organization`);
    
    if (usersSnapshot.docs.length === 0) {
      console.log('❌ No active users found in this organization');
      console.log('💡 This explains why push notifications aren\'t working');
      
      // Let's check all users regardless of organization
      const allUsersSnapshot = await db.collection('users').limit(5).get();
      console.log(`📊 Found ${allUsersSnapshot.docs.length} users total (limited to 5)`);
      
      allUsersSnapshot.docs.forEach((doc, index) => {
        const userData = doc.data();
        console.log(`User ${index + 1}: ${doc.id}`);
        console.log(`  Email: ${userData.email || userData.userEmail || 'N/A'}`);
        console.log(`  Organization: ${userData.organizationId || 'N/A'}`);
        console.log(`  Active: ${userData.isActive}`);
        console.log(`  Last FCM Token: ${userData.lastFcmToken ? 'Present' : 'None'}`);
      });
      
      process.exit(0);
    }
    
    // Check tokens for each user
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      console.log(`\n👤 User: ${userId}`);
      console.log(`   Email: ${userData.email || userData.userEmail || 'N/A'}`);
      console.log(`   Last FCM Token: ${userData.lastFcmToken ? 'Present' : 'None'}`);
      
      // Check user's device tokens subcollection
      const tokensSnapshot = await db.collection('users')
        .doc(userId)
        .collection('deviceTokens')
        .where('isActive', '==', true)
        .get();
      
      console.log(`   Device Tokens: ${tokensSnapshot.docs.length} active`);
      
      tokensSnapshot.docs.forEach((tokenDoc, index) => {
        const tokenData = tokenDoc.data();
        console.log(`     Token ${index + 1}: ${tokenData.fcmToken ? 'Present' : 'Missing'}`);
        console.log(`     Platform: ${tokenData.platform || 'Unknown'}`);
        console.log(`     Updated: ${tokenData.updatedAt ? tokenData.updatedAt.toDate() : 'Unknown'}`);
      });
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkUsersAndTokens();
