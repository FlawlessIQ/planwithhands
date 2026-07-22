const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

// Access the specific "planwithhands" database (not default)
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function listDatabases() {
  try {
    console.log('🔍 Checking Firestore configuration...\n');
    console.log('Project ID: plan-with-hands');
    console.log('Database ID: (default)\n');
    
    // Try to list some collections to verify connection
    console.log('Attempting to list collections...');
    const collections = await db.listCollections();
    console.log(`Found ${collections.length} root collections:`);
    collections.forEach(col => {
      console.log(`  - ${col.id}`);
    });
    
    // Try to get one organization document
    if (collections.some(c => c.id === 'organizations')) {
      console.log('\n📊 Sampling organizations collection...');
      const orgsSnapshot = await db.collection('organizations').limit(5).get();
      console.log(`Found ${orgsSnapshot.docs.length} organizations (first 5):`);
      orgsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${doc.id}: ${data.name || 'Unnamed'}`);
      });
      
      // Check if our specific org exists
      console.log('\n🔍 Checking for specific organization...');
      const orgDoc = await db.collection('organizations').doc('FErQ4pkcrCovJ7T6L13M').get();
      if (orgDoc.exists) {
        console.log('✅ Found organization FErQ4pkcrCovJ7T6L13M');
        console.log('   Name:', orgDoc.data().name);
      } else {
        console.log('❌ Organization FErQ4pkcrCovJ7T6L13M not found');
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error('\nFull error:', error.stack);
  } finally {
    process.exit(0);
  }
}

listDatabases();
