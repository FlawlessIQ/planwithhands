const admin = require('firebase-admin');

// Initialize Firebase Admin for the correct project
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'  // Explicitly specify the project
  });
}

const db = admin.firestore();

async function queryPlanWithHandsDatabase() {
  console.log('🔍 Querying PLANWITHHANDS Firestore database...');
  console.log('📊 Project ID: plan-with-hands');
  
  try {
    // First, let's see what organizations exist
    console.log('\n📋 Listing all organizations...');
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`   Found ${orgsSnapshot.size} organizations`);
    
    const realOrgs = [];
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgName = orgData.name || orgData.organizationName || 'NO NAME';
      
      console.log(`\n🏢 ${orgName} (${orgDoc.id})`);
      
      if (orgName !== 'NO NAME' && orgName !== 'Unknown') {
        realOrgs.push({
          id: orgDoc.id, 
          name: orgName, 
          data: orgData
        });
        
        // Check locations for this org
        const locationsSnapshot = await db.collection('organizations')
          .doc(orgDoc.id)
          .collection('locations')
          .get();
        
        console.log(`   📍 Locations: ${locationsSnapshot.size}`);
        
        for (const locationDoc of locationsSnapshot.docs) {
          const locationData = locationDoc.data();
          console.log(`      - ${locationData.name || 'Unnamed'} (${locationDoc.id})`);
        }
      }
    }
    
    console.log(`\n✅ Found ${realOrgs.length} organizations with real names`);
    
    // Now check for today's problematic checklists
    const today = '2025-10-02';
    console.log(`\n🔍 Checking for checklists dated: ${today}`);
    
    let totalProblematic = 0;
    
    for (const org of realOrgs) {
      console.log(`\n🏢 Checking ${org.name}...`);
      
      const locationsSnapshot = await db.collection('organizations')
        .doc(org.id)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationData = locationDoc.data();
        console.log(`\n   📍 ${locationData.name}`);
        
        // Get all checklists for today
        const checklistsSnapshot = await db.collection('organizations')
          .doc(org.id)
          .collection('locations')
          .doc(locationDoc.id)
          .collection('dailyChecklists')
          .where('date', '==', today)
          .get();
        
        console.log(`      📋 Checklists for ${today}: ${checklistsSnapshot.size}`);
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const templateName = checklistData.templateName || 'NO NAME';
          const templateIds = checklistData.templateIds || [];
          const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
          
          const isProblematic = templateName === 'Unknown Template' ||
                               templateName === 'NO NAME' ||
                               templateIds.length === 0;
          
          if (isProblematic) {
            console.log(`         🚨 PROBLEMATIC: "${templateName}" (${taskCount} tasks)`);
            console.log(`            🆔 ID: ${checklistDoc.id}`);
            console.log(`            🏷️  Template IDs: ${JSON.stringify(templateIds)}`);
            totalProblematic++;
          } else {
            console.log(`         ✅ OK: "${templateName}" (${taskCount} tasks)`);
          }
        }
      }
    }
    
    console.log(`\n📊 SUMMARY:`);
    console.log(`   Total problematic checklists found for ${today}: ${totalProblematic}`);
    
    if (totalProblematic > 0) {
      console.log(`\n🚨 ACTION NEEDED: Found ${totalProblematic} problematic checklists!`);
    } else {
      console.log(`\n✅ No problematic checklists found for today`);
      console.log(`   The Unknown Template you're seeing might be:`);
      console.log(`   1. From a previous date`);
      console.log(`   2. A client-side caching issue`);
      console.log(`   3. Created with a different date format`);
    }
    
  } catch (error) {
    console.error('❌ Error querying database:', error);
    console.error('   Make sure you have proper Firestore permissions');
  }
}

queryPlanWithHandsDatabase().then(() => {
  console.log('\n🏁 Query complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});