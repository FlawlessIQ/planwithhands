// Check for organizations with actual users and data
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

// Use the correct database (planwithhands instead of default)
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function findActiveOrganizations() {
  console.log('🔍 Looking for organizations with actual users...');
  
  try {
    // Find organizations by looking at users first
    const allUsersSnapshot = await db.collection('users').limit(50).get();
    console.log(`Found ${allUsersSnapshot.docs.length} total users`);
    
    const orgIds = new Set();
    const orgUserCounts = {};
    const orgAdminCounts = {};
    
    for (const userDoc of allUsersSnapshot.docs) {
      const userData = userDoc.data();
      const orgId = userData.organizationId;
      
      if (orgId) {
        orgIds.add(orgId);
        orgUserCounts[orgId] = (orgUserCounts[orgId] || 0) + 1;
        
        if (userData.userRole >= 1 && userData.isActive) {
          orgAdminCounts[orgId] = (orgAdminCounts[orgId] || 0) + 1;
        }
      }
    }
    
    console.log(`\nFound ${orgIds.size} unique organizations with users:`);
    
    for (const orgId of orgIds) {
      console.log(`\n🏢 Organization: ${orgId}`);
      console.log(`   Total users: ${orgUserCounts[orgId]}`);
      console.log(`   Admin users: ${orgAdminCounts[orgId] || 0}`);
      
      // Get org details
      const orgDoc = await db.collection('organizations').doc(orgId).get();
      if (orgDoc.exists) {
        const orgData = orgDoc.data();
        console.log(`   Name: ${orgData.name || orgData.organizationName || 'Unknown'}`);
        console.log(`   Timezone: ${orgData.timezone || 'NOT SET'}`);
      } else {
        console.log('   Organization document not found!');
      }
      
      // Check locations
      const locationsQuery = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      console.log(`   Locations: ${locationsQuery.docs.length}`);
      for (const locDoc of locationsQuery.docs) {
        const locData = locDoc.data();
        console.log(`     - ${locData.locationName || 'Unknown'}: timezone = ${locData.timezone || 'NOT SET'}`);
      }
      
      // Check recent daily checklists to see if there's actual activity
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayStr = yesterday.toISOString().split('T')[0];
      
      let totalChecklists = 0;
      for (const locDoc of locationsQuery.docs) {
        const checklistQuery = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locDoc.id)
          .collection('daily_checklists')
          .where('date', '==', yesterdayStr)
          .get();
        totalChecklists += checklistQuery.docs.length;
      }
      
      console.log(`   Daily checklists for yesterday: ${totalChecklists}`);
      
      // Check for daily summary logs
      const logDoc = await db
        .collection('organizations')
        .doc(orgId)
        .collection('daily_summary_logs')
        .doc(yesterdayStr)
        .get();
      
      if (logDoc.exists) {
        console.log(`   ✅ Daily summary sent for yesterday`);
      } else {
        console.log(`   ❌ No daily summary sent for yesterday`);
      }
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit(0);
}

findActiveOrganizations();
