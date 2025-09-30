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

async function findHamiltonPorkOrg() {
  console.log('🔍 Looking for Hamilton Pork organization...');
  
  try {
    // Search all organizations for ones that might contain "Hamilton" or "Pork"
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`Total organizations found: ${orgsSnapshot.size}`);
    
    const matches = [];
    
    orgsSnapshot.forEach(doc => {
      const data = doc.data();
      const name = (data.name || data.organizationName || '').toLowerCase();
      const businessName = (data.businessName || '').toLowerCase();
      
      if (name.includes('hamilton') || name.includes('pork') || 
          businessName.includes('hamilton') || businessName.includes('pork')) {
        matches.push({
          id: doc.id,
          name: data.name || data.organizationName || data.businessName || 'Unnamed',
          businessType: data.businessType || 'Unknown'
        });
      }
    });

    console.log(`\nOrganizations matching "Hamilton" or "Pork": ${matches.length}`);
    matches.forEach(org => {
      console.log(`  ${org.id}: ${org.name} (${org.businessType})`);
    });

    // If no exact matches, let's look for organizations with locations named Hamilton Pork
    if (matches.length === 0) {
      console.log('\nSearching for organizations with "Hamilton Pork" locations...');
      
      for (const orgDoc of orgsSnapshot.docs) {
        try {
          const locationsSnapshot = await db.collection('organizations').doc(orgDoc.id).collection('locations').get();
          
          locationsSnapshot.forEach(locationDoc => {
            const locationData = locationDoc.data();
            const locationName = (locationData.name || '').toLowerCase();
            
            if (locationName.includes('hamilton') && locationName.includes('pork')) {
              console.log(`  Found in org ${orgDoc.id}: ${locationData.name}`);
              matches.push({
                id: orgDoc.id,
                name: orgDoc.data().name || orgDoc.data().organizationName || 'Unnamed',
                locationId: locationDoc.id,
                locationName: locationData.name
              });
            }
          });
        } catch (error) {
          // Skip if can't access locations
        }
      }
    }

    // Let's also check the specific org ID format - maybe it's a different case or has extra characters
    console.log('\nTrying variations of the org ID...');
    const variations = [
      'FErQ4pkcrCovJ7T6L13M',
      'ferq4pkcrcovj7t6l13m',
      'FERQ4PKCRCOVJ7T6L13M'
    ];

    for (const variation of variations) {
      try {
        const orgDoc = await db.collection('organizations').doc(variation).get();
        if (orgDoc.exists) {
          console.log(`  Found with variation: ${variation}`);
          const data = orgDoc.data();
          console.log(`    Name: ${data.name || data.organizationName || 'Unnamed'}`);
        }
      } catch (error) {
        // Skip
      }
    }

    return matches;

  } catch (error) {
    console.error('Error:', error.message);
    return [];
  }
}

findHamiltonPorkOrg().then((matches) => {
  if (matches.length > 0) {
    console.log('\n✅ Found potential matches. Use the correct org ID for further investigation.');
  } else {
    console.log('\n❌ No matching organizations found. The org ID might be incorrect or from a different environment.');
  }
  process.exit(0);
}).catch(error => {
  console.error('Failed:', error);
  process.exit(1);
});