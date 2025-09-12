const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function parallelCleanup() {
  console.log('🚨 PARALLEL EMERGENCY CLEANUP - MAXIMUM SPEED');
  console.log('=============================================\n');

  const problematicOrgId = 'vnE0olvi1Tswjtdb19MI';
  
  console.log(`🎯 Targeting organization: ${problematicOrgId}`);
  console.log('⚡ PARALLEL PROCESSING - Multiple batches simultaneously');
  console.log('⚠️  This will delete ALL notifications from the last 6 hours\n');
  
  try {
    const notificationsRef = planWithHandsDb
      .collection('organizations')
      .doc(problematicOrgId)
      .collection('notifications');
    
    const sixHoursAgo = new Date(Date.now() - (6 * 60 * 60 * 1000));
    
    let totalDeleted = 0;
    let roundNumber = 1;
    const batchSize = 1000;
    const parallelBatches = 5; // Process 5 batches simultaneously = 5000 docs at once
    
    console.log(`🕐 Deleting all notifications newer than: ${sixHoursAgo.toLocaleString()}`);
    console.log(`⚡ Processing ${parallelBatches} batches of ${batchSize} docs in parallel = ${parallelBatches * batchSize} docs per round\n`);
    
    while (true) {
      console.log(`🗑️  Round ${roundNumber} - Processing ${parallelBatches} parallel batches...`);
      
      // Create multiple batch promises to run in parallel
      const batchPromises = [];
      
      for (let i = 0; i < parallelBatches; i++) {
        const batchPromise = async () => {
          const batch = await notificationsRef
            .where('createdAt', '>', sixHoursAgo)
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
      
      // Progress milestones
      if (totalDeleted % 50000 === 0) {
        console.log(`\n🎯 MILESTONE: ${totalDeleted.toLocaleString()} notifications deleted`);
        
        // Check remaining count periodically
        try {
          const remainingQuery = await notificationsRef
            .where('createdAt', '>', sixHoursAgo)
            .count()
            .get();
          console.log(`📊 Estimated remaining: ${remainingQuery.data().count.toLocaleString()}\n`);
        } catch (countError) {
          console.log('📊 Could not get remaining count (too many docs)\n');
        }
      }
      
      // Very minimal delay since we're doing parallel processing
      await new Promise(resolve => setTimeout(resolve, 5));
    }
    
    console.log(`\n🎯 PARALLEL CLEANUP SUMMARY`);
    console.log(`Total notifications deleted: ${totalDeleted.toLocaleString()}`);
    console.log(`Rounds processed: ${(roundNumber - 1).toLocaleString()}`);
    console.log(`Average per round: ${Math.round(totalDeleted / (roundNumber - 1)).toLocaleString()} docs`);
    
    // Final check
    const finalCount = await notificationsRef.count().get();
    console.log(`\n📊 Final notification count in org: ${finalCount.data().count.toLocaleString()}`);
    
    if (finalCount.data().count < 100) {
      console.log('✅ SUCCESS: Notification count is now reasonable!');
    } else {
      console.log('⚠️  Still high numbers remaining. Consider running again.');
    }
    
  } catch (error) {
    console.error('❌ Parallel cleanup failed:', error);
    throw error;
  }
}

// Immediate execution
console.log('🚨 PARALLEL CLEANUP - MAXIMUM SPEED MODE');
console.log('This processes 5000 documents per round using parallel batches.');
console.log('Press Ctrl+C within 3 seconds to cancel...\n');

setTimeout(() => {
  parallelCleanup()
    .then(() => {
      console.log('\n✅ Parallel cleanup complete!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Cleanup failed:', error);
      process.exit(1);
    });
}, 3000);
