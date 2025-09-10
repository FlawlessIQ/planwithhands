const {admin, db} = require("./functions/firebase_config");

async function fixExistingChecklists() {
  console.log('🔧 Starting to fix existing checklists without job types...');
  
  try {
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      console.log(`📋 Processing organization: ${orgId}`);
      
      // Get all locations for this org
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        console.log(`  📍 Processing location: ${locationId}`);
        
        // Get all daily checklists for this location
        const checklistsSnapshot = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .get();
        
        const batch = db.batch();
        let updateCount = 0;
        const maxBatchSize = 500; // Firestore batch limit
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          const templateId = checklistData.checklistTemplateId;
          
          // Skip if no template ID or already has job types
          if (!templateId || checklistData.jobTypes) {
            continue;
          }
          
          try {
            // Get the template to fetch job types
            const templateDoc = await db
              .collection('organizations')
              .doc(orgId)
              .collection('checklist_templates')
              .doc(templateId)
              .get();
            
            if (templateDoc.exists) {
              const templateData = templateDoc.data();
              const jobTypes = templateData.jobTypes || templateData.jobType;
              
              if (jobTypes) {
                // Update the checklist with job types from template
                batch.update(checklistDoc.ref, {
                  jobTypes: Array.isArray(jobTypes) ? jobTypes : [jobTypes],
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                updateCount++;
                console.log(`    ✅ Queued update for checklist ${checklistDoc.id} with jobTypes: ${JSON.stringify(jobTypes)}`);
                
                // Commit batch if we hit the size limit
                if (updateCount >= maxBatchSize) {
                  await batch.commit();
                  console.log(`  💾 Committed batch of ${updateCount} updates for location ${locationId}`);
                  updateCount = 0;
                }
              }
            }
          } catch (e) {
            console.log(`    ❌ Error processing checklist ${checklistDoc.id}: ${e.message}`);
          }
        }
        
        // Commit any remaining updates in the batch
        if (updateCount > 0) {
          await batch.commit();
          console.log(`  ✅ Updated ${updateCount} checklists in location ${locationId}`);
        } else {
          console.log(`  ℹ️ No checklists needed updating in location ${locationId}`);
        }
      }
    }
    
    console.log('🎉 Finished fixing existing checklists!');
  } catch (e) {
    console.log(`❌ Error fixing checklists: ${e.message}`);
    console.error(e);
  }
}

// Run the fix
fixExistingChecklists().then(() => {
  console.log('Script completed successfully');
  process.exit(0);
}).catch((error) => {
  console.error('Script failed:', error);
  process.exit(1);
});
