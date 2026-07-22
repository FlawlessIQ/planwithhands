const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://planwithhands-default-rtdb.firebaseio.com/'
  });
}

const db = admin.firestore();

async function findRealOrganizations() {
  console.log('🔍 Searching for organizations with real names...');
  
  try {
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`📊 Total organizations: ${orgsSnapshot.size}`);
    
    const realOrgs = [];
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgName = orgData.name;
      
      // Skip organizations with "Unknown" or empty names
      if (orgName && orgName !== 'Unknown' && orgName.trim() !== '') {
        console.log(`\n🏢 Found: ${orgName} (${orgDoc.id})`);
        realOrgs.push({id: orgDoc.id, name: orgName, data: orgData});
        
        // Check if it has locations
        const locationsSnapshot = await db.collection('organizations').doc(orgDoc.id).collection('locations').get();
        console.log(`   📍 Locations: ${locationsSnapshot.size}`);
        
        if (locationsSnapshot.size > 0) {
          for (const locationDoc of locationsSnapshot.docs) {
            const locationData = locationDoc.data();
            console.log(`      - ${locationData.name || 'Unnamed'} (${locationDoc.id})`);
          }
        }
      }
    }
    
    console.log(`\n📊 Found ${realOrgs.length} organizations with real names`);
    
    // If we found real organizations, check for today's checklists
    if (realOrgs.length > 0) {
      console.log('\n🔍 Checking these organizations for today\'s checklists...');
      
      const today = '2025-10-02';
      
      for (const org of realOrgs) {
        console.log(`\n🏢 Checking ${org.name} (${org.id})`);
        
        const locationsSnapshot = await db.collection('organizations').doc(org.id).collection('locations').get();
        
        for (const locationDoc of locationsSnapshot.docs) {
          const locationData = locationDoc.data();
          console.log(`\n   📍 ${locationData.name || 'Unnamed'}`);
          
          const checklistsSnapshot = await db.collection('organizations')
            .doc(org.id)
            .collection('locations')
            .doc(locationDoc.id)
            .collection('dailyChecklists')
            .where('date', '==', today)
            .get();
          
          console.log(`      📋 Today's checklists: ${checklistsSnapshot.size}`);
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
            const isProblematic = !checklistData.templateName || 
                                 checklistData.templateName === 'Unknown Template' ||
                                 !checklistData.templateIds || 
                                 checklistData.templateIds.length === 0;
            
            console.log(`         ${isProblematic ? '🚨' : '✅'} ${checklistData.templateName || 'NO NAME'} (${taskCount} tasks)`);
            
            if (isProblematic) {
              console.log(`            📝 Template IDs: ${JSON.stringify(checklistData.templateIds || [])}`);
              console.log(`            🆔 Checklist ID: ${checklistDoc.id}`);
            }
          }
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

findRealOrganizations().then(() => {
  console.log('\n🏁 Search complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});