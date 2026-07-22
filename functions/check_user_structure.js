const admin = require('firebase-admin');

admin.initializeApp();

async function checkUserStructure() {
  try {
    const userId = 'ah9OSUi87LhFTkewui8gZVM3ijC2';
    
    console.log('🔍 Checking user document locations...');
    
    // Check direct users collection
    console.log('1. Checking users/' + userId);
    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        console.log('✅ Found in users collection:', userDoc.data());
      } else {
        console.log('❌ Not found in users collection');
      }
    } catch (e) {
      console.log('❌ Error checking users collection:', e.message);
    }
    
    // Check org-specific users
    const orgId = 'UnfSxn25GWnbrrahhGRa';
    console.log('2. Checking organizations/' + orgId + '/users/' + userId);
    try {
      const orgUserDoc = await admin.firestore()
        .collection('organizations')
        .doc(orgId)
        .collection('users')
        .doc(userId)
        .get();
      if (orgUserDoc.exists) {
        console.log('✅ Found in org users collection:', orgUserDoc.data());
      } else {
        console.log('❌ Not found in org users collection');
      }
    } catch (e) {
      console.log('❌ Error checking org users collection:', e.message);
    }
    
    // List all collections to understand structure
    console.log('3. Listing all root collections...');
    const collections = await admin.firestore().listCollections();
    console.log('Root collections:', collections.map(c => c.id));
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkUserStructure();
