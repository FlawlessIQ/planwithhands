#!/usr/bin/env node

/**
 * Clean up all problematic checklists with no template IDs
 * This will remove the checklists created by the Cloud Function before we added validation
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with correct database
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function cleanupProblematicChecklists() {
  console.log('🧹 Cleaning up problematic checklists...');
  
  try {
    // Get all organizations
    const orgsSnap = await db.collection('organizations').get();
    console.log(`📊 Checking ${orgsSnap.docs.length} organizations`);
    
    let totalFound = 0;
    let totalCleaned = 0;
    
    for (const orgDoc of orgsSnap.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.name || orgData.organizationName || orgId;
      
      console.log(`\n🏢 Processing org: ${orgName} (${orgId})`);
      
      // Get locations for this org
      const locationsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      if (locationsSnap.docs.length === 0) {
        console.log('   📍 No locations found');
        continue;
      }
      
      for (const locDoc of locationsSnap.docs) {
        const locationId = locDoc.id;
        const locationData = locDoc.data();
        const locationName = locationData.locationName || locationId;
        
        // Get checklists with no template IDs from last week
        const weekAgo = new Date();
        weekAgo.setDate(weekAgo.getDate() - 7);
        const weekAgoString = weekAgo.toISOString().split('T')[0];
        
        const checklistsSnap = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', '>=', weekAgoString)
          .get();
        
        if (checklistsSnap.docs.length === 0) continue;
        
        let locationProblematic = 0;
        let locationCleaned = 0;
        
        console.log(`   📍 Processing location: ${locationName}`);
        
        // Process in batches to avoid hitting Firestore limits
        const batchSize = 10;
        const batches = [];
        for (let i = 0; i < checklistsSnap.docs.length; i += batchSize) {
          batches.push(checklistsSnap.docs.slice(i, i + batchSize));
        }
        
        for (const batch of batches) {
          const deleteBatch = db.batch();
          let batchCount = 0;
          
          for (const checklistDoc of batch) {
            const checklistData = checklistDoc.data();
            const templateIds = checklistData.checklistTemplateIds || [];
            
            // Only delete checklists with no template IDs (the problematic ones)
            if (templateIds.length === 0) {
              totalFound++;
              locationProblematic++;
              
              // Delete all tasks in the checklist first
              const tasksSnap = await checklistDoc.ref.collection('tasks').get();
              tasksSnap.docs.forEach(taskDoc => {
                deleteBatch.delete(taskDoc.ref);
              });
              
              // Delete the checklist itself
              deleteBatch.delete(checklistDoc.ref);
              batchCount++;
              
              console.log(`     ❌ Marked for deletion: ${checklistDoc.id} (${checklistData.date})`);
            }
          }
          
          if (batchCount > 0) {
            await deleteBatch.commit();
            totalCleaned += batchCount;
            locationCleaned += batchCount;
            console.log(`     ✅ Deleted batch of ${batchCount} checklists`);
          }
        }
        
        if (locationProblematic > 0) {
          console.log(`   📊 Location summary: ${locationProblematic} problematic, ${locationCleaned} cleaned`);
        }
      }
    }
    
    console.log(`\n📊 Final Summary:`);
    console.log(`   Total problematic checklists found: ${totalFound}`);
    console.log(`   Total checklists cleaned up: ${totalCleaned}`);
    
    if (totalCleaned > 0) {
      console.log(`\n✅ Cleanup complete! The Unknown Template issue should now be resolved.`);
      console.log(`\n🚀 Next steps:`);
      console.log(`   1. Cloud Function fix is deployed to prevent new issues`);
      console.log(`   2. Existing problematic checklists have been removed`);
      console.log(`   3. Web app should now show proper templates when joining shifts`);
    } else {
      console.log(`\n💡 No problematic checklists found to clean up.`);
    }
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
}

// Run the cleanup
cleanupProblematicChecklists().then(() => {
  console.log('🏁 Cleanup complete');
  process.exit(0);
});