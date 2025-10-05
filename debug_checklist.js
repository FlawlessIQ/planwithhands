/**
 * Debug the actual checklist document structure
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function debugChecklist() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const locationId = 'fW45ffBBPar5EaNodDYq';
  const checklistId = 'FErQ4pkcrCovJ7T6L13M_fW45ffBBPar5EaNodDYq_VY0xGrIzvHSaqX1AXkcY_2025-10-03';

  console.log('\n=== DEBUG CHECKLIST DOCUMENT ===\n');
  console.log(`Checklist ID: ${checklistId}\n`);

  try {
    const checklistRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .doc(checklistId);

    const checklistDoc = await checklistRef.get();
    
    if (checklistDoc.exists) {
      const data = checklistDoc.data();
      
      console.log('Full checklist document:');
      console.log(JSON.stringify(data, null, 2));
      
      console.log('\n=== KEY FIELDS ===\n');
      console.log(`ID field: ${data.id || '(missing)'}`);
      console.log(`checklistTemplateId: ${data.checklistTemplateId || '(missing)'}`);
      console.log(`checklistTemplateIds (array): ${JSON.stringify(data.checklistTemplateIds || '(missing)')}`);
      console.log(`templateName: ${data.templateName || '(missing)'}`);
      console.log(`shiftId: ${data.shiftId}`);
      console.log(`date: ${data.date}`);
      console.log(`createdBy: ${data.createdBy}`);
      
      // Check if there's an array of template IDs stored
      if (Array.isArray(data.checklistTemplateIds)) {
        console.log('\n⚠️  PROBLEM FOUND: checklistTemplateIds is an ARRAY, not a single ID!');
        console.log(`Array contains: ${data.checklistTemplateIds.join(', ')}`);
        console.log('\nThis means the generator is creating ONE checklist for MULTIPLE templates,');
        console.log('instead of creating SEPARATE checklists for each template.');
      }
      
      // Check tasks subcollection
      console.log('\n=== TASKS SUBCOLLECTION ===\n');
      const tasksSnap = await checklistRef.collection('tasks').limit(5).get();
      console.log(`Found ${tasksSnap.size} tasks (showing first 5)`);
      
      tasksSnap.docs.forEach((taskDoc, index) => {
        const taskData = taskDoc.data();
        console.log(`\nTask ${index + 1}:`);
        console.log(`  ID: ${taskDoc.id}`);
        console.log(`  Name: ${taskData.taskName}`);
        console.log(`  Template Task ID: ${taskData.templateTaskId || '(missing)'}`);
        console.log(`  Checklist Template ID: ${taskData.checklistTemplateId || '(missing)'}`);
      });
      
    } else {
      console.log('❌ Checklist document not found');
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

debugChecklist()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
