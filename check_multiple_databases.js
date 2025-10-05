const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

async function checkMultipleDatabases() {
  console.log('🔍 Checking for multiple Firestore databases...');
  
  try {
    // Try to connect to the default database
    console.log('\n📊 Connecting to DEFAULT database...');
    const defaultDb = admin.firestore();
    
    const defaultOrgsSnapshot = await defaultDb.collection('organizations').limit(3).get();
    console.log(`   Default database - Organizations: ${defaultOrgsSnapshot.size}`);
    
    if (defaultOrgsSnapshot.size > 0) {
      for (const orgDoc of defaultOrgsSnapshot.docs) {
        const orgData = orgDoc.data();
        console.log(`      - ${orgData.name || 'NO NAME'} (${orgDoc.id})`);
      }
    }
    
    // Try to connect to a specific database named "planwithhands"
    console.log('\n📊 Trying to connect to PLANWITHHANDS database...');
    try {
      const planWithHandsDb = admin.firestore('planwithhands');
      const planWithHandsOrgsSnapshot = await planWithHandsDb.collection('organizations').limit(3).get();
      console.log(`   PlanWithHands database - Organizations: ${planWithHandsOrgsSnapshot.size}`);
      
      if (planWithHandsOrgsSnapshot.size > 0) {
        for (const orgDoc of planWithHandsOrgsSnapshot.docs) {
          const orgData = orgDoc.data();
          console.log(`      - ${orgData.name || 'NO NAME'} (${orgDoc.id})`);
          
          // Check if this org has locations
          const locationsSnapshot = await planWithHandsDb.collection('organizations')
            .doc(orgDoc.id)
            .collection('locations')
            .get();
          console.log(`         📍 Locations: ${locationsSnapshot.size}`);
          
          if (locationsSnapshot.size > 0) {
            for (const locationDoc of locationsSnapshot.docs) {
              const locationData = locationDoc.data();
              console.log(`            - ${locationData.name || 'Unnamed'}`);
            }
            
            // Check for today's checklists
            const today = '2025-10-02';
            for (const locationDoc of locationsSnapshot.docs) {
              const checklistsSnapshot = await planWithHandsDb.collection('organizations')
                .doc(orgDoc.id)
                .collection('locations')
                .doc(locationDoc.id)
                .collection('dailyChecklists')
                .where('date', '==', today)
                .get();
              
              console.log(`            📋 Today's checklists: ${checklistsSnapshot.size}`);
              
              for (const checklistDoc of checklistsSnapshot.docs) {
                const checklistData = checklistDoc.data();
                const templateName = checklistData.templateName || 'NO NAME';
                const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
                
                if (templateName === 'Unknown Template' || !checklistData.templateIds || checklistData.templateIds.length === 0) {
                  console.log(`               🚨 FOUND UNKNOWN TEMPLATE: "${templateName}" (${taskCount} tasks)`);
                }
              }
            }
          }
        }
      }
    } catch (planWithHandsError) {
      console.log(`   ❌ Could not connect to 'planwithhands' database: ${planWithHandsError.message}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkMultipleDatabases().then(() => {
  console.log('\n🏁 Database check complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});