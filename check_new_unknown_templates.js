const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://planwithhands-default-rtdb.firebaseio.com/'
  });
}

const db = admin.firestore();

async function checkNewUnknownTemplates() {
  console.log('🔍 Checking for new Unknown Template checklists created after cleanup...');
  
  try {
    // Check for checklists created today (October 2, 2025)
    const today = new Date('2025-10-02');
    const todayStr = today.toISOString().split('T')[0];
    
    console.log(`📅 Looking for checklists from ${todayStr}`);
    
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    
    let totalFound = 0;
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      console.log(`\n🏢 Checking org: ${orgData.name || 'Unknown'} (${orgId})`);
      
      // Get locations
      const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
      
      if (locationsSnapshot.empty) {
        console.log('   📍 No locations found');
        continue;
      }
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationData = locationDoc.data();
        console.log(`   📍 Checking location: ${locationData.name || 'Unknown'}`);
        
        // Check daily checklists for today
        const checklistsSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('dailyChecklists')
          .where('date', '==', todayStr)
          .get();
        
        let locationProblematic = 0;
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          
          // Check if this checklist has issues
          const hasNoTemplateIds = !checklistData.templateIds || checklistData.templateIds.length === 0;
          const hasEmptyTemplateName = !checklistData.templateName || checklistData.templateName.trim() === '';
          const hasUnknownTemplate = checklistData.templateName === 'Unknown Template';
          
          if (hasNoTemplateIds || hasEmptyTemplateName || hasUnknownTemplate) {
            console.log(`     ❌ PROBLEMATIC: ${checklistDoc.id}`);
            console.log(`        📝 Template Name: "${checklistData.templateName || 'MISSING'}"`);
            console.log(`        🏷️  Template IDs: ${JSON.stringify(checklistData.templateIds || [])}`);
            console.log(`        📊 Task Count: ${checklistData.tasks ? Object.keys(checklistData.tasks).length : 0}`);
            console.log(`        ⏰ Created: ${checklistData.createdAt ? checklistData.createdAt.toDate() : 'Unknown'}`);
            
            locationProblematic++;
            totalFound++;
          }
        }
        
        if (locationProblematic > 0) {
          console.log(`   📊 Location summary: ${locationProblematic} problematic checklists found`);
        } else {
          console.log(`   ✅ Location clean: No problematic checklists`);
        }
      }
    }
    
    console.log(`\n📊 FINAL SUMMARY:`);
    console.log(`   Total new problematic checklists found: ${totalFound}`);
    
    if (totalFound > 0) {
      console.log(`\n🚨 WARNING: New Unknown Template checklists have been created since cleanup!`);
      console.log(`   This suggests either:`);
      console.log(`   1. Cloud Function fix didn't deploy properly`);
      console.log(`   2. Client-side logic is still creating problematic checklists`);
      console.log(`   3. There's another code path creating these checklists`);
    } else {
      console.log(`\n✅ Good news: No new problematic checklists created since cleanup`);
    }
    
  } catch (error) {
    console.error('❌ Error checking checklists:', error);
  }
}

checkNewUnknownTemplates().then(() => {
  console.log('🏁 Check complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});