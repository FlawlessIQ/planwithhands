const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function continuousCleanup() {
  console.log('🚨 CONTINUOUS CLEANUP - NO STOPPING UNTIL COMPLETE');
  console.log('==================================================\n');

  const problematicOrgId = 'vnE0olvi1Tswjtdb19MI';
  
  console.log(`🎯 Targeting organization: ${problematicOrgId}`);
  console.log('⚡ CONTINUOUS PROCESSING - Will not stop until no more docs found');
  console.log('⚠️  This will delete ALL notifications from the last 8 hours\n');
  
  try {
    const notificationsRef = planWithHandsDb
      .collection('organizations')
      .doc(problematicOrgId)
      .collection('notifications');
    
    const eightHoursAgo = new Date(Date.now() - (8 * 60 * 60 * 1000));
    
    let totalDeleted = 0;
    let roundNumber = 1;
    const batchSize = 1000;
    const parallelBatches = 3; // Reduced to 3 for stability
    
    console.log(`🕐 Deleting all notifications newer than: ${eightHoursAgo.toLocaleString()}`);
    console.log(`⚡ Processing ${parallelBatches} batches of ${batchSize} docs in parallel\n`);
    
    while (true) {
      console.log(`🗑️  Round ${roundNumber} - Processing ${parallelBatches} parallel batches... (Total so far: ${totalDeleted.toLocaleString()})`);
      
      // Create multiple batch promises to run in parallel
      const batchPromises = [];
      
      for (let i = 0; i < parallelBatches; i++) {
        const batchPromise = async () => {
          try {
            const batch = await notificationsRef
              .where('createdAt', '>', eightHoursAgo)
              .limit(batchSize)
              .get();
            
            if (batch.empty) {
              return 0; // No docs found
            }
            
            // Delete this batch using Firestore batch operations (max 500)
            const deleteBatches = [];
            for (let j = 0; j < batch.docs.length; j += 500) {
              const deleteBatch = planWithHandsDb.batch();
              const batchChunk = batch.docs.slice(j, j + 500);
              
              batchChunk.forEach(doc => {
                deleteBatch.delete(doc.ref);
              });
              
              deleteBatches.push(deleteBatch.commit());
            }
            
            await Promise.all(deleteBatches);
            return batch.size;
          } catch (error) {
            console.error(`   ❌ Batch error:`, error.message);
            return 0;
          }
        };
        
        batchPromises.push(batchPromise());
      }
      
      // Wait for all parallel batches to complete
      const results = await Promise.all(batchPromises);
      const roundDeleted = results.reduce((sum, count) => sum + count, 0);
      
      if (roundDeleted === 0) {
        console.log('✅ No more recent notifications found - cleanup complete!');
        break;
      }
      
      totalDeleted += roundDeleted;
      console.log(`   ✅ Round ${roundNumber} deleted ${roundDeleted} notifications (Total: ${totalDeleted.toLocaleString()})`);
      
      roundNumber++;
      
      // Progress updates every 10k instead of 50k
      if (totalDeleted % 10000 === 0) {
        console.log(`\n🎯 PROGRESS: ${totalDeleted.toLocaleString()} notifications deleted`);
        
        // Quick remaining check without stopping
        try {
          const remainingQuery = await notificationsRef
            .where('createdAt', '>', eightHoursAgo)
            .limit(1)
            .get();
          
          if (!remainingQuery.empty) {
            console.log(`📊 More notifications still found - continuing...\n`);
          } else {
            console.log(`📊 No more notifications found - will exit after this check\n`);
          }
        } catch (countError) {
          console.log('📊 Continuing cleanup...\n');
        }
      }
      
      // Minimal delay
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    
    console.log(`\n🎯 CONTINUOUS CLEANUP SUMMARY`);
    console.log(`Total notifications deleted: ${totalDeleted.toLocaleString()}`);
    console.log(`Rounds processed: ${(roundNumber - 1).toLocaleString()}`);
    
    // Final verification
    try {
      const finalQuery = await notificationsRef
        .where('createdAt', '>', eightHoursAgo)
        .limit(1)
        .get();
      
      if (finalQuery.empty) {
        console.log('✅ SUCCESS: No more recent notifications found!');
      } else {
        console.log('⚠️  Some notifications may still remain.');
      }
    } catch (error) {
      console.log('📊 Could not verify final state');
    }
    
  } catch (error) {
    console.error('❌ Continuous cleanup failed:', error);
    console.log(`💾 Progress before failure: ${totalDeleted.toLocaleString()} notifications deleted`);
    throw error;
  }
}

// Immediate execution
console.log('🚨 CONTINUOUS CLEANUP - WILL NOT STOP');
console.log('Press Ctrl+C within 2 seconds to cancel...\n');

setTimeout(() => {
  continuousCleanup()
    .then(() => {
      console.log('\n✅ Continuous cleanup complete!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Cleanup failed:', error);
      process.exit(1);
    });
}, 2000);
