const admin = require('firebase-admin');

// Initialize Firebase Admin with the planwithhands database
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com/'
  });
}

// Use the planwithhands database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function findDailySummarySettings(orgId) {
  console.log(`🔍 Searching for daily summary settings for org: ${orgId}`);
  
  try {
    // Check multiple possible locations
    const locations = [
      'organizations/{orgId}/settings/dailySummarySettings',
      'organizations/{orgId}/dailySummarySettings',
      'dailySummarySettings/{orgId}',
      'organizations/{orgId}/settings/daily_summary'
    ];
    
    for (const location of locations) {
      const path = location.replace('{orgId}', orgId);
      console.log(`\n📍 Checking: ${path}`);
      
      let doc;
      if (path.includes('organizations')) {
        if (path.includes('settings/')) {
          const parts = path.split('/');
          doc = await db.collection(parts[0]).doc(parts[1]).collection(parts[2]).doc(parts[3]).get();
        } else {
          const parts = path.split('/');
          doc = await db.collection(parts[0]).doc(parts[1]).collection(parts[2]).doc();
        }
      } else {
        const parts = path.split('/');
        doc = await db.collection(parts[0]).doc(parts[1]).get();
      }
      
      if (doc && doc.exists) {
        console.log(`✅ Found settings at: ${path}`);
        console.log('   Data:', doc.data());
      } else {
        console.log(`❌ Not found at: ${path}`);
      }
    }
    
    // Also search the entire organizations doc for any daily summary fields
    console.log(`\n📄 Checking main organization document...`);
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      const dailySummaryFields = {};
      Object.keys(orgData).forEach(key => {
        if (key.toLowerCase().includes('daily') || key.toLowerCase().includes('summary')) {
          dailySummaryFields[key] = orgData[key];
        }
      });
      
      if (Object.keys(dailySummaryFields).length > 0) {
        console.log('✅ Found daily summary fields in main org doc:');
        console.log(dailySummaryFields);
      } else {
        console.log('❌ No daily summary fields in main org doc');
      }
    }
    
    // Search all subcollections of the org
    console.log(`\n🔍 Searching all subcollections...`);
    const orgRef = db.collection('organizations').doc(orgId);
    const collections = await orgRef.listCollections();
    
    for (const collection of collections) {
      console.log(`📁 Checking collection: ${collection.id}`);
      const docs = await collection.limit(5).get();
      
      for (const doc of docs.docs) {
        const data = doc.data();
        if (data && typeof data === 'object') {
          const hasRelevantFields = Object.keys(data).some(key => 
            key.toLowerCase().includes('daily') || 
            key.toLowerCase().includes('summary') ||
            key.toLowerCase().includes('hour') ||
            key.toLowerCase().includes('minute')
          );
          
          if (hasRelevantFields) {
            console.log(`   ✅ Found relevant data in ${collection.id}/${doc.id}:`, data);
          }
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error searching for settings:', error);
  }
}

// Get orgId from command line argument
const orgId = process.argv[2];
if (!orgId) {
  console.log('Usage: node find_daily_summary_settings.js <orgId>');
  process.exit(1);
}

findDailySummarySettings(orgId).then(() => {
  console.log('\n✅ Search complete');
  process.exit(0);
}).catch(error => {
  console.error('❌ Script error:', error);
  process.exit(1);
});