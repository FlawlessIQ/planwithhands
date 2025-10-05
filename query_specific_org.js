const admin = require('firebase-admin');

// Initialize Firebase Admin for the correct project
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function querySpecificOrganization() {
  console.log('🔍 Querying specific organization from Firebase console screenshot...');
  
  try {
    // From the screenshot, I can see organization ID starting with 3qjYzHagWmfb
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    console.log(`\n🏢 Checking organization: ${orgId}`);
    
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (!orgDoc.exists) {
      console.log('   ❌ Organization not found');
      return;
    }
    
    const orgData = orgDoc.data();
    console.log('   📊 Organization data:');
    console.log(JSON.stringify(orgData, null, 2));
    
    // Check locations
    console.log('\n   📍 Checking locations...');
    const locationsSnapshot = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`      Found ${locationsSnapshot.size} locations`);
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      console.log(`\n      📍 Location: ${locationDoc.id}`);
      console.log(`         Data:`, JSON.stringify(locationData, null, 2));
      
      // Check for today's checklists
      const today = '2025-10-02';
      const checklistsSnapshot = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationDoc.id)
        .collection('dailyChecklists')
        .where('date', '==', today)
        .get();
      
      console.log(`\n         📋 Checklists for ${today}: ${checklistsSnapshot.size}`);
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'NO NAME';
        const templateIds = checklistData.templateIds || [];
        const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
        
        console.log(`\n            📋 ${checklistDoc.id}`);
        console.log(`               Template: "${templateName}"`);
        console.log(`               Template IDs: ${JSON.stringify(templateIds)}`);
        console.log(`               Tasks: ${taskCount}`);
        console.log(`               Created: ${checklistData.createdAt ? checklistData.createdAt.toDate() : 'Unknown'}`);
        
        if (templateName === 'Unknown Template' || templateIds.length === 0) {
          console.log(`               🚨 PROBLEMATIC CHECKLIST FOUND!`);
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

querySpecificOrganization().then(() => {
  console.log('\n🏁 Query complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});