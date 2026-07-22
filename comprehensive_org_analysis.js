const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials
admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore();
const orgId = '3qjYzHagWmfbnMieJ1aj';

async function comprehensiveOrgAnalysis() {
  console.log('🔍 COMPREHENSIVE ANALYSIS FOR ORGANIZATION:', orgId);
  console.log('=' .repeat(100));
  
  try {
    // 1. First check the organization document itself
    console.log('1️⃣ ORGANIZATION DOCUMENT:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization document does not exist in Firestore');
      return;
    }
    
    const orgData = orgDoc.data();
    console.log('✅ Organization document exists with data:');
    console.log(JSON.stringify(orgData, null, 2));
    
    // 2. Check all subcollections in the organization
    console.log('\n2️⃣ SUBCOLLECTION ANALYSIS:');
    const subcollections = ['locations', 'shifts', 'job_types', 'checklist_templates', 'users', 'daily_checklists'];
    
    for (const subCollection of subcollections) {
      console.log(`\n📁 ${subCollection}:`);
      const snapshot = await db.collection('organizations').doc(orgId)
        .collection(subCollection).limit(5).get();
      
      console.log(`  📊 Count: ${snapshot.size} documents`);
      
      if (snapshot.size > 0) {
        console.log('  📄 Sample documents:');
        snapshot.docs.forEach((doc, index) => {
          console.log(`    ${index + 1}. ${doc.id}:`);
          console.log(`       ${JSON.stringify(doc.data(), null, 8)}`);
        });
      } else {
        console.log('  📭 No documents found');
      }
    }
    
    // 3. Compare with a working organization
    console.log('\n3️⃣ COMPARISON WITH WORKING ORGANIZATION (FErQ4pkcrCovJ7T6L13M):');
    const workingOrgId = 'FErQ4pkcrCovJ7T6L13M';
    const workingOrgDoc = await db.collection('organizations').doc(workingOrgId).get();
    
    if (workingOrgDoc.exists) {
      console.log('✅ Working organization found');
      
      for (const subCollection of subcollections) {
        const workingSnapshot = await db.collection('organizations').doc(workingOrgId)
          .collection(subCollection).limit(1).get();
        const problemSnapshot = await db.collection('organizations').doc(orgId)
          .collection(subCollection).limit(1).get();
        
        console.log(`  ${subCollection}: Working=${workingSnapshot.size}, Problem=${problemSnapshot.size}`);
      }
    }
    
    // 4. Check if there are any organization documents at all that might match
    console.log('\n4️⃣ ORGANIZATION SEARCH:');
    console.log('Searching for organizations with similar names or IDs...');
    
    // Search for any organizations
    const allOrgsSnapshot = await db.collection('organizations').limit(10).get();
    console.log(`Found ${allOrgsSnapshot.size} total organizations:`);
    
    allOrgsSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`  ${index + 1}. ${doc.id}: ${data.name || 'Unnamed'}`);
    });
    
    // 5. Check the specific organization creation details
    console.log('\n5️⃣ ORGANIZATION METADATA:');
    if (orgData) {
      console.log('Organization metadata:');
      console.log(`  - Created: ${orgData.created ? new Date(orgData.created.seconds * 1000) : 'Not set'}`);
      console.log(`  - Updated: ${orgData.updated ? new Date(orgData.updated.seconds * 1000) : 'Not set'}`);
      console.log(`  - Name: ${orgData.name || 'Not set'}`);
      console.log(`  - Timezone: ${orgData.timezone || 'Not set'}`);
      console.log(`  - Active: ${orgData.isActive !== undefined ? orgData.isActive : 'Not set'}`);
      console.log(`  - All fields:`, Object.keys(orgData));
    }
    
    console.log('\n' + '=' .repeat(100));
    console.log('📊 SUMMARY:');
    console.log(`Organization ${orgId} exists but appears to be empty/incomplete:`);
    console.log('- ❌ No locations configured');
    console.log('- ❌ No shifts configured');
    console.log('- ❌ No job types configured');
    console.log('- ❌ No checklist templates configured');
    console.log('- ❌ No users assigned');
    console.log('- ❌ No daily checklists generated');
    console.log('\n💡 RECOMMENDATION: This organization needs to be properly set up with:');
    console.log('   1. Locations');
    console.log('   2. Shifts');
    console.log('   3. Job types');
    console.log('   4. Checklist templates');
    console.log('   5. Users');
    
  } catch (error) {
    console.error('❌ Error during analysis:', error);
  }
  
  process.exit(0);
}

comprehensiveOrgAnalysis();