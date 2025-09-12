const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function unlimitedCleanup() {
  console.log('🚨 UNLIMITED EMERGENCY CLEANUP');
  console.log('==============================\n');

  const problematicOrgId = 'vnE0olvi1Tswjtdb19MI';
  
  console.log(`🎯 Targeting organization: ${problematicOrgId}`);
  console.log('⚠️  NO LIMITS - Will delete until no more recent notifications found');
  console.log('⚠️  This will delete ALL notifications from the last 6 hours\n');
  
  try {
    const notificationsRef = planWithHandsDb
      .collection('organizations')
      .doc(problematicOrgId)
      .collection('notifications');
    
    // Delete ALL notifications from last 6 hours (even more aggressive)
    const sixHoursAgo = new Date(Date.now() - (6 * 60 * 60 * 1000));
    
    let totalDeleted = 0;
    let batchNumber = 1;
    const batchSize = 1000; // Maximum Firestore batch size
    
    console.log(`🕐 Deleting all notifications newer than: ${sixHoursAgo.toLocaleString()}\n`);
    
    while (true) {
      console.log(`🗑️  Processing batch ${batchNumber} (deleted so far: ${totalDeleted})...`);
      
      const batch = await notificationsRef
        .where('createdAt', '>', sixHoursAgo)
        .limit(batchSize)
        .get();
      
      if (batch.empty) {
        console.log('✅ No more recent notifications found - cleanup complete!');
        break;
      }
      
      console.log(`   Found ${batch.size} notifications in this batch`);
      
      // Delete this batch
      const deleteBatch = planWithHandsDb.batch();
      batch.docs.forEach(doc => {
        deleteBatch.delete(doc.ref);
      });
      
      await deleteBatch.commit();
      totalDeleted += batch.size;
      
      console.log(`   ✅ Deleted ${batch.size} notifications (Total: ${totalDeleted})`);
      
      batchNumber++;
      
      // Progress milestones
      if (totalDeleted % 50000 === 0) {
        console.log(`\n🎯 MILESTONE: ${totalDeleted} notifications deleted`);
        
        // Check remaining count periodically
        try {
          const remainingQuery = await notificationsRef
            .where('createdAt', '>', sixHoursAgo)
            .count()
            .get();
          console.log(`📊 Estimated remaining: ${remainingQuery.data().count}\n`);
        } catch (countError) {
          console.log('📊 Could not get remaining count (too many docs)\n');
        }
      }
      
      // NO SAFETY LIMITS - keep going until done!
      
      // Minimal delay to avoid overwhelming Firestore
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    
    console.log(`\n🎯 UNLIMITED CLEANUP SUMMARY`);
    console.log(`Total notifications deleted: ${totalDeleted.toLocaleString()}`);
    console.log(`Batches processed: ${(batchNumber - 1).toLocaleString()}`);
    
    // Final check
    const finalCount = await notificationsRef.count().get();
    console.log(`\n📊 Final notification count in org: ${finalCount.data().count.toLocaleString()}`);
    
    if (finalCount.data().count < 100) {
      console.log('✅ SUCCESS: Notification count is now reasonable!');
    } else {
      console.log('⚠️  Still high numbers remaining. Consider expanding time window further.');
    }
    
  } catch (error) {
    console.error('❌ Unlimited cleanup failed:', error);
    throw error;
  }
}

// Immediate execution with shorter warning
console.log('🚨 UNLIMITED CLEANUP - NO SAFETY LIMITS');
console.log('This will delete ALL notifications from the last 6 hours.');
console.log('Given the scale of this emergency, no deletion limits are enforced.');
console.log('Press Ctrl+C within 5 seconds to cancel...\n');

setTimeout(() => {
  unlimitedCleanup()
    .then(() => {
      console.log('\n✅ Unlimited cleanup complete!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Cleanup failed:', error);
      process.exit(1);
    });
}, 5000);
