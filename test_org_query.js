const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Admin SDK with application default credentials
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = new Firestore({ 
  databaseId: 'planwithhands',
  projectId: 'plan-with-hands'
});

async function checkOrganizationQuery() {
  console.log('\n🔍 Testing organization query behavior...\n');
  
  try {
    // Test the exact same query the scheduled function uses
    console.log('1. Running the same query as the scheduled function:');
    console.log('   db.collection("organizations").get()');
    
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`   Found ${orgsSnapshot.size} organizations\n`);
    
    console.log('2. Organizations found by the query:');
    orgsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      const orgName = data.organizationName || data.name || 'Unknown';
      console.log(`   ${index + 1}. ${doc.id} - ${orgName}`);
    });
    
    console.log('\n3. Checking if Hamilton Pork is included:');
    const hamiltonDoc = orgsSnapshot.docs.find(doc => doc.id === 'FErQ4pkcrCovJ7T6L13M');
    if (hamiltonDoc) {
      console.log('   ✅ Hamilton Pork IS included in the query results');
      const hamiltonData = hamiltonDoc.data();
      console.log(`   Name: ${hamiltonData.organizationName || hamiltonData.name || 'Unknown'}`);
      console.log(`   Daily Summary Enabled: ${hamiltonData.dailySummarySettings?.enabled}`);
    } else {
      console.log('   ❌ Hamilton Pork is NOT included in the query results');
      console.log('   This explains why the scheduled function is not checking it!');
    }
    
    console.log('\n4. Directly checking Hamilton Pork document:');
    const directDoc = await db.collection('organizations').doc('FErQ4pkcrCovJ7T6L13M').get();
    console.log(`   Direct access exists: ${directDoc.exists ? '✅ YES' : '❌ NO'}`);
    
    if (directDoc.exists) {
      const directData = directDoc.data();
      console.log(`   Direct name: ${directData.organizationName || directData.name || 'Unknown'}`);
      console.log(`   Direct daily summary enabled: ${directData.dailySummarySettings?.enabled}`);
    }
    
    console.log('\n5. Checking for any query constraints or limits:');
    console.log('   The query appears to be a simple .get() with no where clauses or limits');
    console.log('   This suggests a potential Firestore consistency or permissions issue');
    
  } catch (error) {
    console.error('❌ Error during organization query test:', error);
  }
}

checkOrganizationQuery().then(() => {
  console.log('\n✅ Organization query test complete');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});