const admin = require('firebase-admin');

admin.initializeApp();

async function findUserDocument() {
  try {
    const userId = 'ah9OSUi87LhFTkewui8gZVM3ijC2';
    const orgId = 'UnfSxn25GWnbrrahhGRa';
    
    console.log('🔍 Deep search for user document...');
    
    // Check the organization document itself
    console.log('1. Checking organization document...');
    const orgDoc = await admin.firestore().collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      console.log('✅ Organization exists, checking subcollections...');
      
      // List all subcollections in the organization
      const orgSubcollections = await admin.firestore()
        .collection('organizations')
        .doc(orgId)
        .listCollections();
      
      console.log('Organization subcollections:', orgSubcollections.map(c => c.id));
      
      // Check if user is in members or similar collection
      for (const subcollection of orgSubcollections) {
        console.log(`\n2. Checking ${subcollection.id} subcollection...`);
        
        if (subcollection.id === 'members' || subcollection.id === 'users' || subcollection.id.includes('user')) {
          try {
            const userDoc = await subcollection.doc(userId).get();
            if (userDoc.exists) {
              console.log(`✅ Found user in ${subcollection.id}:`, userDoc.data());
              return;
            }
          } catch (e) {
            console.log(`❌ Error checking ${subcollection.id}:`, e.message);
          }
        }
        
        // List some documents in this subcollection
        try {
          const docs = await subcollection.limit(3).get();
          console.log(`   Sample docs in ${subcollection.id}:`, docs.docs.map(d => d.id));
        } catch (e) {
          console.log(`   Cannot list docs in ${subcollection.id}:`, e.message);
        }
      }
    }
    
    // Maybe it's in a different structure - let's try to find any document with this user ID
    console.log('\n3. Searching for user ID pattern in organizations...');
    
    // Check if there's a users collection at root that we missed
    try {
      const rootUsers = await admin.firestore().collection('users').limit(5).get();
      if (!rootUsers.empty) {
        console.log('✅ Found users collection at root with docs:', rootUsers.docs.map(d => d.id));
      }
    } catch (e) {
      console.log('❌ No users collection at root or error:', e.message);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

findUserDocument();
