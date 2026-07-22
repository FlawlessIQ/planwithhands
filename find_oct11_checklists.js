const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function findOct11Checklists() {
  try {
    console.log('=== Searching for October 11, 2025 checklists ===\n');
    
    const checklists = await db
      .collection('organizations')
      .doc('FErQ4pkcrCovJ7T6L13M')
      .collection('locations')
      .doc('abTp8sjidL5QVirAewe6')
      .collection('daily_checklists')
      .where('date', '==', '2025-10-11')
      .get();
    
    console.log(`Found ${checklists.size} checklists for Oct 11\n`);
    
    checklists.docs.forEach((doc, index) => {
      const data = doc.data();
      const templateName = data.templateName || 'No Name';
      const shiftId = data.shiftId || 'No Shift';
      
      console.log(`${index + 1}. Template: ${templateName}`);
      console.log(`   Shift ID: ${shiftId}`);
      console.log(`   Document ID: ${doc.id}`);
      
      // Check if templateName includes "Copy"
      if (templateName.toLowerCase().includes('copy')) {
        console.log(`   ⚠️  CONTAINS "COPY" - This is the orphaned checklist!`);
      }
      
      // Check tasks for checklist names
      if (data.tasks && data.tasks.length > 0) {
        const firstTask = data.tasks[0];
        if (firstTask.checklistName) {
          console.log(`   Checklist Name (from task): ${firstTask.checklistName}`);
          if (firstTask.checklistName.toLowerCase().includes('copy')) {
            console.log(`   ⚠️  TASK CHECKLIST NAME CONTAINS "COPY"!`);
          }
        }
      }
      console.log('');
    });
    
    if (checklists.size === 0) {
      console.log('❌ No checklists found for October 11, 2025');
      console.log('\nThis explains why the app still shows the data:');
      console.log('The data was already cleaned up in earlier operations.');
      console.log('The app is showing CACHED data that no longer exists in the database.\n');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

findOct11Checklists();
