const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function inspectStructure() {
  try {
    console.log('=== Inspecting Chickies Checklist Structure ===\n');
    
    const checklists = await db
      .collection('organizations')
      .doc('FErQ4pkcrCovJ7T6L13M')
      .collection('locations')
      .doc('abTp8sjidL5QVirAewe6')
      .collection('daily_checklists')
      .limit(3)
      .get();
    
    console.log(`Showing structure of first ${checklists.size} checklists:\n`);
    
    checklists.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`${index + 1}. Document ID: ${doc.id}`);
      console.log('   Fields:', Object.keys(data).join(', '));
      console.log('   Full data:', JSON.stringify(data, null, 2));
      console.log('');
    });

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

inspectStructure();
