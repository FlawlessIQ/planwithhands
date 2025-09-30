const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();
// Make sure we're using the planwithhands database, not the default
db.settings({
  databaseId: 'planwithhands'
});

async function quickOrgCheck() {
  console.log('🔍 Quick organization check for: FErQ4pkcrCovJ7T6L13M');
  
  const orgId = 'FErQ4pkcrCovJ7T6L13M';

  try {
    // Check if org exists
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    console.log(`Organization exists: ${orgDoc.exists}`);
    
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log('Org data keys:', Object.keys(orgData));
      console.log('Name:', orgData.name || orgData.organizationName || 'Unknown');
    }

    // List all subcollections
    const collections = await db.collection('organizations').doc(orgId).listCollections();
    console.log('Available subcollections:');
    collections.forEach(collection => {
      console.log('  -', collection.id);
    });

    // Check locations specifically
    const locationsRef = db.collection('organizations').doc(orgId).collection('locations');
    const locationsSnapshot = await locationsRef.get();
    console.log(`\nLocations found: ${locationsSnapshot.size}`);
    
    locationsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`  ${doc.id}: ${data.name || 'Unnamed'}`);
    });

  } catch (error) {
    console.error('Error:', error.message);
  }
}

quickOrgCheck().then(() => {
  process.exit(0);
}).catch(error => {
  console.error('Failed:', error);
  process.exit(1);
});