const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function querySpecificOrgAndLocations() {
  console.log('🔍 Querying the SPECIFIC organization and locations from app logs...');
  
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locationIds = ['3mkG9233plgeu94IVE71', 'EazZJYpWQB8XWHw464C2', 'sYhcOTkX1VkeoPjtPuwZ'];
  
  console.log(`🏢 Organization ID: ${orgId}`);
  console.log(`📍 Location IDs: ${locationIds.join(', ')}`);
  
  try {
    // First check the organization
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    
    const orgData = orgDoc.data();
    console.log(`\n📊 Organization data:`);
    console.log(`   Name: ${orgData.name || 'NO NAME'}`);
    console.log(`   Settings:`, JSON.stringify(orgData.settings, null, 2));
    
    // Check each location
    for (const locationId of locationIds) {
      console.log(`\n📍 Checking location: ${locationId}`);
      
      const locationDoc = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .get();
      
      if (!locationDoc.exists) {
        console.log(`   ❌ Location ${locationId} not found!`);
        continue;
      }
      
      const locationData = locationDoc.data();
      console.log(`   📛 Name: ${locationData.name || 'NO NAME'}`);
      console.log(`   📊 Data:`, JSON.stringify(locationData, null, 2));
      
      // Check for today's checklists
      const today = '2025-10-02';
      console.log(`\n   📋 Checking checklists for ${today}...`);
      
      const checklistsSnapshot = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('dailyChecklists')
        .where('date', '==', today)
        .get();
      
      console.log(`      Found ${checklistsSnapshot.size} checklists`);
      
      let unknownTemplateFound = false;
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'NO NAME';
        const templateIds = checklistData.templateIds || checklistData.checklistTemplateIds || [];
        const taskCount = checklistData.tasks ? Object.keys(checklistData.tasks).length : 0;
        
        console.log(`\n      📋 ${checklistDoc.id}`);
        console.log(`         📝 Template: "${templateName}"`);
        console.log(`         🏷️  Template IDs: ${JSON.stringify(templateIds)}`);
        console.log(`         📊 Tasks: ${taskCount}`);
        console.log(`         ⏰ Created: ${checklistData.createdAt ? checklistData.createdAt.toDate() : 'Unknown'}`);
        
        if (templateName === 'Unknown Template') {
          unknownTemplateFound = true;
          console.log(`         🚨 FOUND THE UNKNOWN TEMPLATE CHECKLIST!`);
          
          // Get a sample of tasks to understand the structure
          if (checklistData.tasks) {
            const taskKeys = Object.keys(checklistData.tasks);
            console.log(`         📝 Sample tasks (first 3 of ${taskKeys.length}):`);
            for (let i = 0; i < Math.min(3, taskKeys.length); i++) {
              const taskKey = taskKeys[i];
              const task = checklistData.tasks[taskKey];
              console.log(`            - ${task.name || task.taskName || 'Unnamed task'}`);
            }
          }
        }
      }
      
      if (!unknownTemplateFound) {
        console.log(`      ✅ No Unknown Template checklists found for this location today`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

querySpecificOrgAndLocations().then(() => {
  console.log('\n🏁 Query complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});