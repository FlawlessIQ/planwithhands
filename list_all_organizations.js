const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();

async function listAllOrganizations() {
  console.log('🔍 Listing ALL organizations in the database...');
  
  try {
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`📊 Total organizations found: ${orgsSnapshot.size}`);
    
    const orgList = [];
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgInfo = {
        id: orgDoc.id,
        name: orgData.name || 'NO NAME',
        hasLocations: false,
        locationCount: 0
      };
      
      // Check if it has locations
      const locationsSnapshot = await db.collection('organizations').doc(orgDoc.id).collection('locations').get();
      orgInfo.hasLocations = !locationsSnapshot.empty;
      orgInfo.locationCount = locationsSnapshot.size;
      
      orgList.push(orgInfo);
    }
    
    // Sort by name
    orgList.sort((a, b) => a.name.localeCompare(b.name));
    
    console.log('\n📋 Organizations list:');
    orgList.forEach((org, index) => {
      const locationInfo = org.hasLocations ? `${org.locationCount} locations` : 'no locations';
      console.log(`   ${index + 1}. ${org.name} (${org.id}) - ${locationInfo}`);
    });
    
    // Look for organizations that might be Hamilton Pork or similar
    console.log('\n🔍 Looking for organizations with "Hamilton", "Pork", "Conor", "Hudson" in name...');
    const relevantOrgs = orgList.filter(org => {
      const name = org.name.toLowerCase();
      return name.includes('hamilton') || name.includes('pork') || name.includes('conor') || name.includes('hudson');
    });
    
    if (relevantOrgs.length > 0) {
      console.log('🎯 Found relevant organizations:');
      relevantOrgs.forEach(org => {
        console.log(`   - ${org.name} (${org.id})`);
      });
    } else {
      console.log('❌ No relevant organizations found with expected names');
    }
    
    // Check organizations with most locations
    console.log('\n🏗️  Organizations with most locations:');
    const orgsWithLocations = orgList.filter(org => org.hasLocations).sort((a, b) => b.locationCount - a.locationCount);
    orgsWithLocations.slice(0, 10).forEach(org => {
      console.log(`   ${org.name}: ${org.locationCount} locations`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

listAllOrganizations().then(() => {
  console.log('\n🏁 Complete');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});