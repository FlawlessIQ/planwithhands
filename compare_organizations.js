const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');

async function compareOrganizations() {
  console.log('🔍 COMPARING ORGANIZATIONS');
  console.log('=' .repeat(80));
  
  const problemOrgId = '3qjYzHagWmfbnMieJ1aj';
  const workingOrgId = 'FErQ4pkcrCovJ7T6L13M';
  
  try {
    console.log(`Problem Org: ${problemOrgId}`);
    console.log(`Working Org: ${workingOrgId}`);
    console.log('-' .repeat(80));
    
    const subcollections = ['locations', 'shifts', 'job_types', 'checklist_templates', 'users'];
    
    for (const subCollection of subcollections) {
      console.log(`\n📁 ${subCollection.toUpperCase()}:`);
      
      // Check problem org
      const problemSnapshot = await db.collection('organizations').doc(problemOrgId)
        .collection(subCollection).limit(3).get();
      
      // Check working org
      const workingSnapshot = await db.collection('organizations').doc(workingOrgId)
        .collection(subCollection).limit(3).get();
      
      console.log(`  Problem Org (${problemOrgId}): ${problemSnapshot.size} documents`);
      console.log(`  Working Org (${workingOrgId}): ${workingSnapshot.size} documents`);
      
      if (workingSnapshot.size > 0) {
        console.log(`  Sample from working org:`);
        workingSnapshot.docs.slice(0, 1).forEach((doc) => {
          const data = doc.data();
          console.log(`    ${doc.id}: ${JSON.stringify(data, null, 6)}`);
        });
      }
    }
    
    // Check main org documents
    console.log('\n📄 ORGANIZATION DOCUMENTS:');
    
    const problemOrgDoc = await db.collection('organizations').doc(problemOrgId).get();
    const workingOrgDoc = await db.collection('organizations').doc(workingOrgId).get();
    
    if (problemOrgDoc.exists && workingOrgDoc.exists) {
      const problemData = problemOrgDoc.data();
      const workingData = workingOrgDoc.data();
      
      console.log('\nProblem org fields:', Object.keys(problemData));
      console.log('Working org fields:', Object.keys(workingData));
      
      console.log('\nProblem org name:', problemData.name || 'NOT SET');
      console.log('Working org name:', workingData.name || 'NOT SET');
    }
    
  } catch (error) {
    console.error('❌ Error comparing organizations:', error);
  }
  
  process.exit(0);
}

compareOrganizations();