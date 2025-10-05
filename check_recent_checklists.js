const admin = require('firebase-admin');

// Initialize Firebase Admin with application default credentials
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function checkRecentChecklists() {
  console.log('🔍 Checking recent checklists and missed tasks...');
  
  try {
    // Check dates around October 2, 2025
    const dates = ['2025-10-01', '2025-10-02', '2025-10-03'];
    
    for (const date of dates) {
      console.log(`\n📅 Checking date: ${date}`);
      
      let dateTotal = 0;
      let unknownCount = 0;
      
      // Get organizations with real names
      const orgsSnapshot = await db.collection('organizations').get();
      
      for (const orgDoc of orgsSnapshot.docs) {
        const orgData = orgDoc.data();
        const orgId = orgDoc.id;
        const orgName = orgData.name;
        
        // Skip organizations without real names
        if (!orgName || orgName === 'Unknown' || orgName.trim() === '') continue;
        
        const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
        
        for (const locationDoc of locationsSnapshot.docs) {
          const locationData = locationDoc.data();
          const locationId = locationDoc.id;
          
          const checklistsSnapshot = await db.collection('organizations')
            .doc(orgId)
            .collection('locations')
            .doc(locationId)
            .collection('dailyChecklists')
            .where('date', '==', date)
            .get();
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            dateTotal++;
            
            const isUnknownTemplate = checklistData.templateName === 'Unknown Template' ||
                                     !checklistData.templateName ||
                                     checklistData.templateName.trim() === '' ||
                                     !checklistData.templateIds ||
                                     checklistData.templateIds.length === 0;
            
            if (isUnknownTemplate) {
              const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
              console.log(`   🚨 ${orgName} - ${locationData.name}: Unknown Template (${taskCount} tasks)`);
              console.log(`      📋 ID: ${checklistDoc.id}`);
              unknownCount++;
            }
          }
        }
      }
      
      console.log(`   📊 Date summary: ${dateTotal} total, ${unknownCount} unknown templates`);
    }
    
    // Now let's check Hamilton Pork specifically to understand the current state
    console.log(`\n🔍 Detailed check of Hamilton Pork organization...`);
    
    const hamiltonQuery = await db.collection('organizations')
      .where('name', '==', 'Hamilton Pork')
      .get();
    
    if (!hamiltonQuery.empty) {
      const hamiltonDoc = hamiltonQuery.docs[0];
      const hamiltonId = hamiltonDoc.id;
      console.log(`   🏢 Found Hamilton Pork: ${hamiltonId}`);
      
      const locationsSnapshot = await db.collection('organizations').doc(hamiltonId).collection('locations').get();
      console.log(`   📍 Locations: ${locationsSnapshot.size}`);
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationData = locationDoc.data();
        console.log(`\n      📍 ${locationData.name} (${locationDoc.id})`);
        
        // Check recent checklists
        const recentChecklistsSnapshot = await db.collection('organizations')
          .doc(hamiltonId)
          .collection('locations')
          .doc(locationDoc.id)
          .collection('dailyChecklists')
          .orderBy('date', 'desc')
          .limit(5)
          .get();
        
        console.log(`         📋 Recent checklists: ${recentChecklistsSnapshot.size}`);
        
        for (const checklistDoc of recentChecklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
          const missedTaskCount = checklistData.missedTasks ? Object.keys(checklistData.missedTasks).length : 0;
          
          console.log(`            📅 ${checklistData.date}: ${checklistData.templateName || 'NO NAME'}`);
          console.log(`               📊 ${taskCount} tasks, ${missedTaskCount} missed tasks`);
          console.log(`               🏷️  Template IDs: ${JSON.stringify(checklistData.templateIds || [])}`);
        }
      }
    } else {
      console.log(`   ❌ Hamilton Pork organization not found!`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkRecentChecklists().then(() => {
  console.log('\n🏁 Check complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});