const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function checkDeletionStatus() {
  console.log('🔍 CHECKING DELETION STATUS');
  console.log('============================\n');

  const problematicOrgId = 'vnE0olvi1Tswjtdb19MI';
  
  try {
    const notificationsRef = planWithHandsDb
      .collection('organizations')
      .doc(problematicOrgId)
      .collection('notifications');
    
    console.log('📊 Checking if any notifications remain...');
    
    // Quick check - just get 1 document
    const testQuery = await notificationsRef.limit(1).get();
    
    if (testQuery.empty) {
      console.log('✅ SUCCESS: No notifications found - deletion is COMPLETE!');
      console.log('🎉 The Firebase CLI deletion has finished successfully.');
    } else {
      console.log('⏳ STILL DELETING: Found notifications - deletion in progress...');
      
      // Try to get a count (may fail if too many docs)
      try {
        const countQuery = await notificationsRef.count().get();
        console.log(`📈 Estimated remaining: ${countQuery.data().count.toLocaleString()}`);
      } catch (countError) {
        console.log('📈 Too many documents to count - deletion still in progress');
      }
    }
    
  } catch (error) {
    console.error('❌ Error checking status:', error);
  }
}

checkDeletionStatus()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Check failed:', error);
    process.exit(1);
  });
