const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function massCleanup() {
  console.log('🚨 MASS CLEANUP - REMOVE ALL RECENT NOTIFICATIONS');
  console.log('================================================\n');

  const problematicOrgId = 'vnE0olvi1Tswjtdb19MI';
  
  console.log(`🎯 Targeting organization: ${problematicOrgId}`);
  console.log('⚠️  This will delete ALL notifications from the last 4 hours');
  console.log('⚠️  This is more aggressive but necessary given the scale\n');
  
  try {
    const notificationsRef = planWithHandsDb
      .collection('organizations')
      .doc(problematicOrgId)
      .collection('notifications');
    
    // Delete ALL notifications from last 4 hours (more aggressive)
    const fourHoursAgo = new Date(Date.now() - (4 * 60 * 60 * 1000));
    
    let totalDeleted = 0;
    let batchNumber = 1;
    const batchSize = 1000; // Larger batches for faster cleanup
    
    while (true) {
      console.log(`🗑️  Processing batch ${batchNumber} (size: ${batchSize})...`);
      
      const batch = await notificationsRef
        .where('createdAt', '>', fourHoursAgo)
        .limit(batchSize)
        .get();
      
      if (batch.empty) {
        console.log('✅ No more recent notifications found');
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
      
      // No safety limit - keep going until done
      if (batchNumber > 1000) { // But still have a sanity check for 1M+ records
        console.log('⚠️  Sanity limit reached (1000 batches). Check if more remain.');
        break;
      }
      
      // Even smaller delay for faster processing
      await new Promise(resolve => setTimeout(resolve, 25));
    }
    
    console.log(`\n🎯 MASS CLEANUP SUMMARY`);
    console.log(`Total notifications deleted: ${totalDeleted}`);
    console.log(`Batches processed: ${batchNumber - 1}`);
    
    // Now check how many notifications remain
    const remainingCount = await notificationsRef.count().get();
    console.log(`\n📊 Remaining notifications in org: ${remainingCount.data().count}`);
    
    if (remainingCount.data().count > 1000) {
      console.log('⚠️  Still high numbers remaining. May need to expand time window or target all notifications.');
    } else {
      console.log('✅ Notification count looks reasonable now.');
    }
    
  } catch (error) {
    console.error('❌ Mass cleanup failed:', error);
    throw error;
  }
}

// Confirm before running
console.log('⚠️  MASS CLEANUP - WILL DELETE ALL RECENT NOTIFICATIONS');
console.log('This will delete ALL notifications from the last 4 hours.');
console.log('Press Ctrl+C within 10 seconds to cancel...\n');

setTimeout(() => {
  massCleanup()
    .then(() => {
      console.log('\n✅ Mass cleanup complete!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Cleanup failed:', error);
      process.exit(1);
    });
}, 10000);
