const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function minimalStatusCheck() {
  console.log('🔍 MINIMAL STATUS CHECK (Spark Plan Safe)');
  console.log('==========================================\n');

  const problematicOrgId = 'vnE0olvi1Tswjtdb19MI';
  
  try {
    const notificationsRef = planWithHandsDb
      .collection('organizations')
      .doc(problematicOrgId)
      .collection('notifications');
    
    console.log('📊 Checking with minimal quota usage...');
    
    // Ultra-minimal check - just get 1 document to test existence
    const testQuery = await notificationsRef.limit(1).get();
    
    if (testQuery.empty) {
      console.log('✅ SUCCESS: Collection appears empty - deletion may be complete!');
    } else {
      console.log('⚠️  WARNING: Documents still exist - but cleanup may be throttled due to quota');
      console.log('❌ You may be stuck with remaining duplicates due to Spark plan limits');
    }
    
  } catch (error) {
    if (error.code === 'resource-exhausted') {
      console.log('❌ QUOTA EXCEEDED: Cannot even check status due to Spark plan limits');
      console.log('💡 You may need to wait 24 hours for quota reset or upgrade plan');
    } else {
      console.error('❌ Error:', error.message);
    }
  }
}

minimalStatusCheck()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Check failed:', error);
    process.exit(1);
  });
