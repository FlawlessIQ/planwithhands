const admin = require('firebase-admin');

// Initialize Firebase Admin with application default credentials
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function findUnknownTemplateChecklists() {
  console.log('🔍 Searching for Unknown Template checklists on October 2, 2025...');
  
  try {
    const today = '2025-10-02';
    
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`📊 Total organizations: ${orgsSnapshot.size}`);
    
    let totalUnknownTemplates = 0;
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgId = orgDoc.id;
      const orgName = orgData.name || 'Unknown';
      
      // Get locations for this org
      const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
      
      if (locationsSnapshot.empty) continue;
      
      let orgHasUnknownTemplates = false;
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationData = locationDoc.data();
        const locationId = locationDoc.id;
        const locationName = locationData.name || 'Unknown';
        
        // Get today's checklists
        const checklistsSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('dailyChecklists')
          .where('date', '==', today)
          .get();
        
        let locationUnknownCount = 0;
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          
          // Check if this is an Unknown Template checklist
          const isUnknownTemplate = checklistData.templateName === 'Unknown Template' ||
                                   !checklistData.templateName ||
                                   checklistData.templateName.trim() === '' ||
                                   !checklistData.templateIds ||
                                   checklistData.templateIds.length === 0;
          
          if (isUnknownTemplate) {
            if (!orgHasUnknownTemplates) {
              console.log(`\n🏢 ${orgName} (${orgId})`);
              orgHasUnknownTemplates = true;
            }
            
            if (locationUnknownCount === 0) {
              console.log(`   📍 ${locationName} (${locationId})`);
            }
            
            const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
            console.log(`      🚨 UNKNOWN TEMPLATE: ${checklistDoc.id}`);
            console.log(`         📝 Template Name: "${checklistData.templateName || 'MISSING'}"`);
            console.log(`         🏷️  Template IDs: ${JSON.stringify(checklistData.templateIds || [])}`);
            console.log(`         📊 Task Count: ${taskCount}`);
            console.log(`         ⏰ Created: ${checklistData.createdAt ? checklistData.createdAt.toDate() : 'Unknown'}`);
            
            locationUnknownCount++;
            totalUnknownTemplates++;
          }
        }
        
        if (locationUnknownCount > 0) {
          console.log(`      📊 Location total: ${locationUnknownCount} Unknown Template checklists`);
        }
      }
    }
    
    console.log(`\n📊 FINAL SUMMARY:`);
    console.log(`   Total Unknown Template checklists found for ${today}: ${totalUnknownTemplates}`);
    
    if (totalUnknownTemplates > 0) {
      console.log(`\n🚨 CRITICAL: Unknown Template checklists are still being created!`);
      console.log(`   This means our fixes from yesterday are not working.`);
    } else {
      console.log(`\n✅ No Unknown Template checklists found for today.`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    
    if (error.message.includes('Could not load the default credentials')) {
      console.log('\n💡 Trying alternative authentication method...');
      
      // Try with application default credentials
      const admin2 = require('firebase-admin');
      if (admin2.apps.length > 0) {
        admin2.apps.forEach(app => app.delete());
      }
      
      admin2.initializeApp({
        credential: admin2.credential.applicationDefault(),
        projectId: 'plan-with-hands'
      });
      
      const db2 = admin2.firestore();
      
      // Retry with simplified query
      console.log('🔄 Retrying with application default credentials...');
      const orgsSnapshot = await db2.collection('organizations').limit(5).get();
      console.log(`📊 Found ${orgsSnapshot.size} organizations (limited sample)`);
      
      for (const orgDoc of orgsSnapshot.docs) {
        const orgData = orgDoc.data();
        console.log(`   - ${orgData.name || 'Unknown'} (${orgDoc.id})`);
      }
    }
  }
}

findUnknownTemplateChecklists().then(() => {
  console.log('\n🏁 Search complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});