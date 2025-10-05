const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function findUnknownTemplateChecklists() {
  console.log('🔍 Searching for ANY checklists with "Unknown Template" in recent days...');
  
  try {
    // Check the last 5 days
    const dates = ['2025-09-28', '2025-09-29', '2025-09-30', '2025-10-01', '2025-10-02'];
    
    console.log(`📅 Checking dates: ${dates.join(', ')}`);
    
    // Get ALL organizations (even those with NO NAME)
    const orgsSnapshot = await db.collection('organizations').get();
    
    let totalUnknownTemplates = 0;
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      
      // Check if this org has any locations at all
      const locationsSnapshot = await db.collection('organizations')
        .doc(orgDoc.id)
        .collection('locations')
        .get();
      
      if (locationsSnapshot.size > 0) {
        console.log(`\n🏢 Checking org: ${orgData.name || 'NO NAME'} (${orgDoc.id})`);
        console.log(`   📍 Locations: ${locationsSnapshot.size}`);
        
        for (const locationDoc of locationsSnapshot.docs) {
          const locationData = locationDoc.data();
          
          for (const date of dates) {
            const checklistsSnapshot = await db.collection('organizations')
              .doc(orgDoc.id)
              .collection('locations')
              .doc(locationDoc.id)
              .collection('dailyChecklists')
              .where('date', '==', date)
              .get();
            
            for (const checklistDoc of checklistsSnapshot.docs) {
              const checklistData = checklistDoc.data();
              const templateName = checklistData.templateName || '';
              
              if (templateName === 'Unknown Template' || 
                  templateName.toLowerCase().includes('unknown')) {
                
                totalUnknownTemplates++;
                const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
                
                console.log(`\n      🚨 FOUND UNKNOWN TEMPLATE:`);
                console.log(`         📋 ID: ${checklistDoc.id}`);
                console.log(`         📅 Date: ${date}`);
                console.log(`         📍 Location: ${locationData.name || 'Unnamed'} (${locationDoc.id})`);
                console.log(`         📝 Template: "${templateName}"`);
                console.log(`         📊 Tasks: ${taskCount}`);
                console.log(`         🏷️  Template IDs: ${JSON.stringify(checklistData.templateIds || [])}`);
                console.log(`         ⏰ Created: ${checklistData.createdAt ? checklistData.createdAt.toDate() : 'Unknown'}`);
              }
            }
          }
        }
      }
    }
    
    console.log(`\n📊 FINAL RESULT:`);
    console.log(`   Total "Unknown Template" checklists found: ${totalUnknownTemplates}`);
    
    if (totalUnknownTemplates === 0) {
      console.log(`\n🤔 No "Unknown Template" checklists found in database for recent dates.`);
      console.log(`   This suggests:`);
      console.log(`   1. The issue might be client-side caching`);
      console.log(`   2. The app might be creating new ones in real-time`);
      console.log(`   3. The template name might be different than "Unknown Template"`);
      console.log(`   4. The data might be in a different collection or format`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

findUnknownTemplateChecklists().then(() => {
  console.log('\n🏁 Search complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});