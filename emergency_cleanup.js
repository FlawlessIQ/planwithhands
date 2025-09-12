const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function emergencyCleanup() {
  console.log('🚨 EMERGENCY NOTIFICATION CLEANUP');
  console.log('==================================\n');

  // Target the most likely problematic organization
  const problematicOrgId = 'vnE0olvi1Tswjtdb19MI'; // This was in the logs
  
  console.log(`🎯 Targeting organization: ${problematicOrgId}`);
  
  try {
    // First, get a count
    const notificationsRef = planWithHandsDb
      .collection('organizations')
      .doc(problematicOrgId)
      .collection('notifications');
    
    // Try to get just the count first
    console.log('📊 Getting notification count...');
    
    // Get recent notifications (likely duplicates) in small batches
    const twoHoursAgo = new Date(Date.now() - (2 * 60 * 60 * 1000));
    
    let deletedCount = 0;
    let batchNumber = 1;
    const batchSize = 100; // Small batches to avoid memory issues
    
    while (true) {
      console.log(`🗑️  Processing batch ${batchNumber}...`);
      
      // Get a small batch of recent notifications
      const batch = await notificationsRef
        .where('createdAt', '>', twoHoursAgo)
        .limit(batchSize)
        .get();
      
      if (batch.empty) {
        console.log('✅ No more recent notifications to delete');
        break;
      }
      
      console.log(`   Found ${batch.size} notifications in this batch`);
      
      // Delete this batch
      const deleteBatch = planWithHandsDb.batch();
      batch.docs.forEach(doc => {
        deleteBatch.delete(doc.ref);
      });
      
      await deleteBatch.commit();
      deletedCount += batch.size;
      
      console.log(`   ✅ Deleted ${batch.size} notifications (Total: ${deletedCount})`);
      
      batchNumber++;
      
      // Safety limit - don't delete more than 10,000 in one run
      if (deletedCount >= 10000) {
        console.log('⚠️  Safety limit reached (10,000 deletions). Run script again if needed.');
        break;
      }
      
      // Small delay to avoid overwhelming Firestore
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log(`\n🎯 CLEANUP SUMMARY`);
    console.log(`Total notifications deleted: ${deletedCount}`);
    
    if (deletedCount >= 10000) {
      console.log('\n⚠️  More duplicates may remain. Re-run this script to continue cleanup.');
      console.log('To run again: node emergency_cleanup.js');
    }
    
  } catch (error) {
    console.error('❌ Emergency cleanup failed:', error);
    throw error;
  }
}

// Confirm before running
console.log('⚠️  EMERGENCY CLEANUP - WILL DELETE RECENT NOTIFICATIONS');
console.log('This will delete notifications created in the last 2 hours.');
console.log('Press Ctrl+C within 5 seconds to cancel...\n');

setTimeout(() => {
  emergencyCleanup()
    .then(() => {
      console.log('\n✅ Emergency cleanup complete!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Cleanup failed:', error);
      process.exit(1);
    });
}, 5000);
