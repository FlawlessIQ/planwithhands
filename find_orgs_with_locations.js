const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function findOrganizationsWithLocations() {
  console.log('🔍 Searching for organizations that have locations...');
  
  try {
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`📊 Total organizations: ${orgsSnapshot.size}`);
    
    const orgsWithLocations = [];
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      
      // Check if this org has locations
      const locationsSnapshot = await db.collection('organizations')
        .doc(orgDoc.id)
        .collection('locations')
        .get();
      
      if (locationsSnapshot.size > 0) {
        console.log(`\n🏢 FOUND ORG WITH LOCATIONS: ${orgDoc.id}`);
        console.log(`   📛 Name in data: ${orgData.name || 'NO NAME'}`);
        console.log(`   📍 Locations: ${locationsSnapshot.size}`);
        
        orgsWithLocations.push({
          id: orgDoc.id,
          data: orgData,
          locationCount: locationsSnapshot.size
        });
        
        // List the locations
        for (const locationDoc of locationsSnapshot.docs) {
          const locationData = locationDoc.data();
          console.log(`      - ${locationData.name || 'Unnamed'} (${locationDoc.id})`);
        }
        
        // Check for today's checklists in this org
        const today = '2025-10-02';
        let totalChecklists = 0;
        let problematicChecklists = 0;
        
        for (const locationDoc of locationsSnapshot.docs) {
          const checklistsSnapshot = await db.collection('organizations')
            .doc(orgDoc.id)
            .collection('locations')
            .doc(locationDoc.id)
            .collection('dailyChecklists')
            .where('date', '==', today)
            .get();
          
          totalChecklists += checklistsSnapshot.size;
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            const templateName = checklistData.templateName || 'NO NAME';
            
            if (templateName === 'Unknown Template' || !checklistData.templateIds || checklistData.templateIds.length === 0) {
              problematicChecklists++;
              console.log(`         🚨 FOUND UNKNOWN TEMPLATE: ${checklistDoc.id}`);
              console.log(`            Template: "${templateName}"`);
              console.log(`            Tasks: ${checklistData.tasks ? Object.keys(checklistData.tasks).length : 0}`);
            }
          }
        }
        
        if (totalChecklists > 0) {
          console.log(`   📋 Today's checklists: ${totalChecklists} (${problematicChecklists} problematic)`);
        }
      }
    }
    
    console.log(`\n📊 SUMMARY:`);
    console.log(`   Organizations with locations: ${orgsWithLocations.length}`);
    
    if (orgsWithLocations.length === 0) {
      console.log(`\n🚨 CRITICAL ISSUE: No organizations have locations!`);
      console.log(`   This suggests a serious database problem or our cleanup script deleted too much.`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

findOrganizationsWithLocations().then(() => {
  console.log('\n🏁 Search complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});