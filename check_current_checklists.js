const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://planwithhands-default-rtdb.firebaseio.com/'
  });
}

const db = admin.firestore();

async function checkCurrentChecklists() {
  console.log('🔍 Checking current checklists for October 2, 2025...');
  
  try {
    // Check for checklists from today
    const today = '2025-10-02';
    
    // Check specific organizations that we know have real names
    const targetOrgs = [
      'FErQ4pkcrCovJ7T6L13M', // Hamilton Pork
      '3qjYzHagWmfbnMieJ1aj', // Conor's pub Group  
      'NTOwK6UJimTs2bADr3qM', // Hudson Hall
      'vnE0olvi1Tswjtdb19MI'  // Flawless Pubs
    ];
    
    for (const orgId of targetOrgs) {
      console.log(`\n🏢 Checking org: ${orgId}`);
      
      const orgDoc = await db.collection('organizations').doc(orgId).get();
      if (!orgDoc.exists) {
        console.log('   ❌ Organization not found');
        continue;
      }
      
      const orgData = orgDoc.data();
      console.log(`   📛 Name: ${orgData.name || 'Unknown'}`);
      
      // Get locations
      const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
      
      if (locationsSnapshot.empty) {
        console.log('   📍 No locations found');
        continue;
      }
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationData = locationDoc.data();
        console.log(`\n   📍 Location: ${locationData.name || 'Unknown'} (${locationId})`);
        
        // Check all checklists for today
        const checklistsSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('dailyChecklists')
          .where('date', '==', today)
          .get();
        
        console.log(`      📊 Found ${checklistsSnapshot.size} checklists for ${today}`);
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
          
          console.log(`      📋 ${checklistDoc.id}`);
          console.log(`         📝 Template: "${checklistData.templateName || 'MISSING'}"`);
          console.log(`         🏷️  Template IDs: ${JSON.stringify(checklistData.templateIds || [])}`);
          console.log(`         📊 Tasks: ${taskCount}`);
          console.log(`         ⏰ Created: ${checklistData.createdAt ? checklistData.createdAt.toDate() : 'Unknown'}`);
          
          // Check if problematic
          const isProblematic = !checklistData.templateName || 
                               checklistData.templateName === 'Unknown Template' ||
                               !checklistData.templateIds || 
                               checklistData.templateIds.length === 0;
          
          if (isProblematic) {
            console.log(`         🚨 PROBLEMATIC CHECKLIST FOUND!`);
          } else {
            console.log(`         ✅ Looks good`);
          }
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkCurrentChecklists().then(() => {
  console.log('\n🏁 Check complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});