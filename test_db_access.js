const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

async function testAccess() {
  try {
    console.log('Testing database access...\n');
    
    // Try planwithhands database with proper initialization
    const db = admin.firestore();
    db.settings({ databaseId: 'planwithhands' });
    
    const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';
    
    const orgDoc = await db.collection('organizations').doc(ORG_ID).get();
    
    if (orgDoc.exists) {
      const data = orgDoc.data();
      console.log('✅ Successfully accessed planwithhands database');
      console.log(`Org Name: ${data.organizationName || data.name || 'Unknown'}`);
      console.log(`Daily Summary Enabled: ${data.dailySummarySettings?.enabled || false}`);
    } else {
      console.log('❌ Organization document not found in planwithhands database');
    }
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    process.exit();
  }
}

testAccess();
