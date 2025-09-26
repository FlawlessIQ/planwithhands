/**
 * Manual cleanup script to remove orphaned daily_checklists that reference deleted template IDs
 * Run this to clean up existing "Unknown Checklist" entries
 */

const admin = require('firebase-admin');

// Use default project config
if (!admin.apps.length) {
  admin.initializeApp();
}

// Use planwithhands database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function cleanupOrphanedDailyChecklists() {
  console.log('🧹 Starting cleanup of orphaned daily_checklists...');
  
  try {
    // Get all organizations
    const orgsSnap = await db.collection('organizations').get();
    
    for (const orgDoc of orgsSnap.docs) {
      const orgId = orgDoc.id;
      console.log(`\n📁 Checking organization: ${orgId}`);
      
      // Get all valid template IDs for this org
      const templatesSnap = await db.collection('organizations').doc(orgId).collection('checklist_templates').get();
      const validTemplateIds = new Set(templatesSnap.docs.map(doc => doc.id));
      console.log(`  ✅ Found ${validTemplateIds.size} valid templates`);
      
      // Get all locations for this org
      const locationsSnap = await db.collection('organizations').doc(orgId).collection('locations').get();
      
      for (const locationDoc of locationsSnap.docs) {
        const locationId = locationDoc.id;
        console.log(`  📍 Checking location: ${locationId}`);
        
        // Get all daily_checklists for this location
        const checklistsSnap = await db.collection('organizations').doc(orgId)
          .collection('locations').doc(locationId)
          .collection('daily_checklists').get();
          
        let orphanedCount = 0;
        let deletedCount = 0;
        let batch = db.batch(); // Create new batch for this location
        let batchCount = 0;
        
        for (const checklistDoc of checklistsSnap.docs) {
          const data = checklistDoc.data();
          const templateId = data.checklistTemplateId;
          
          if (!templateId || !validTemplateIds.has(templateId)) {
            orphanedCount++;
            console.log(`    🗑️  Found orphaned checklist: ${checklistDoc.id} (template: ${templateId || 'undefined'}, date: ${data.date})`);
            
            // Delete tasks subcollection first
            try {
              const tasksSnap = await checklistDoc.ref.collection('tasks').get();
              for (const taskDoc of tasksSnap.docs) {
                batch.delete(taskDoc.ref);
                batchCount++;
              }
            } catch (error) {
              console.log(`    ⚠️  No tasks subcollection for ${checklistDoc.id}`);
            }
            
            // Delete the checklist document
            batch.delete(checklistDoc.ref);
            batchCount++;
            deletedCount++;
            
            // Commit batch if getting too large
            if (batchCount >= 400) {
              await batch.commit();
              console.log(`    💾 Committed batch of ${batchCount} deletions`);
              batch = db.batch(); // Create new batch
              batchCount = 0;
            }
          }
        }
        
        // Commit remaining deletions
        if (batchCount > 0) {
          await batch.commit();
          console.log(`    💾 Committed final batch of ${batchCount} deletions`);
        }
        
        console.log(`  📊 Location ${locationId}: Found ${orphanedCount} orphaned checklists, deleted ${deletedCount}`);
      }
    }
    
    console.log('\n✅ Cleanup completed successfully!');
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
}

// Run the cleanup
cleanupOrphanedDailyChecklists().then(() => {
  console.log('🎉 Cleanup script finished');
  process.exit(0);
}).catch(error => {
  console.error('💥 Cleanup script failed:', error);
  process.exit(1);
});