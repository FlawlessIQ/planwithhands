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

async function compareOrgStructures() {
  try {
    console.log('🔍 Comparing organization structures for notification preferences...\n');
    
    // Get Hamilton Pork org (the one with issues)
    console.log('1. Getting Hamilton Pork organization structure...');
    const hamiltonPorkDoc = await db.collection('organizations').doc('FErQ4pkcrCovJ7T6L13M').get();
    
    if (!hamiltonPorkDoc.exists) {
      console.log('❌ Hamilton Pork organization not found');
      return;
    }
    
    const hamiltonPorkData = hamiltonPorkDoc.data();
    console.log('Hamilton Pork organization structure:');
    console.log(JSON.stringify(hamiltonPorkData, null, 2));
    console.log('\n');
    
    // Find other organizations to compare
    console.log('2. Finding other organizations for comparison...');
    const orgsSnapshot = await db.collection('organizations').limit(5).get();
    
    const orgsWithNotifications = [];
    
    for (const orgDoc of orgsSnapshot.docs) {
      if (orgDoc.id === 'FErQ4pkcrCovJ7T6L13M') continue; // Skip Hamilton Pork
      
      const orgData = orgDoc.data();
      console.log(`\nChecking organization: ${orgData.name} (${orgDoc.id})`);
      
      // Check if this org has notification preferences
      if (orgData.notificationPreferences || orgData.notifications) {
        console.log('✅ Has notification preferences');
        orgsWithNotifications.push({
          id: orgDoc.id,
          name: orgData.name,
          data: orgData
        });
        
        // Show the notification structure
        const notifPrefs = orgData.notificationPreferences || orgData.notifications;
        console.log('Notification structure:');
        console.log(JSON.stringify(notifPrefs, null, 2));
      } else {
        console.log('❌ No notification preferences found');
      }
    }
    
    // Compare user preferences between organizations
    console.log('\n3. Checking user notification preferences in Hamilton Pork...');
    const hamiltonUsers = await db.collection('users')
      .where('organizationId', '==', 'FErQ4pkcrCovJ7T6L13M')
      .get();
    
    console.log(`Found ${hamiltonUsers.size} users in Hamilton Pork`);
    
    for (const userDoc of hamiltonUsers.docs) {
      const userData = userDoc.data();
      console.log(`\nUser: ${userData.firstName} ${userData.lastName} (${userData.email})`);
      
      // Check their notification preferences
      const userNotifRef = db.collection('users').doc(userDoc.id).collection('preferences').doc('notifications');
      const userNotifDoc = await userNotifRef.get();
      
      if (userNotifDoc.exists) {
        const notifData = userNotifDoc.data();
        console.log('User notification preferences:');
        console.log(JSON.stringify(notifData, null, 2));
      } else {
        console.log('❌ No notification preferences document found');
      }
    }
    
    // Summary and recommendations
    console.log('\n📋 SUMMARY:');
    console.log('===========');
    
    if (orgsWithNotifications.length > 0) {
      console.log('✅ Found organizations with notification preferences:');
      orgsWithNotifications.forEach(org => {
        console.log(`   - ${org.name} (${org.id})`);
      });
      
      console.log('\n📝 Recommendation: Add notification preferences to Hamilton Pork based on working examples');
    } else {
      console.log('⚠️  No organizations found with notification preferences structure');
      console.log('   This might be a system-wide configuration issue');
    }
    
  } catch (error) {
    console.error('❌ Error comparing organization structures:', error);
  }
}

compareOrgStructures();