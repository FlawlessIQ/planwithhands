const {Firestore} = require('@google-cloud/firestore');
const db = new Firestore({databaseId: 'planwithhands'});

async function checkTemplate() {
  const templateId = '5e4L09wyBWDZUJROtIeT';
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  // Check template document
  const templateDoc = await db.collection('organizations')
    .doc(orgId)
    .collection('checklist_templates')
    .doc(templateId)
    .get();
  
  console.log('Template exists:', templateDoc.exists);
  if (templateDoc.exists) {
    const data = templateDoc.data();
    console.log('Template data keys:', Object.keys(data));
    console.log('Template name:', data.name);
    console.log('Template tasks field:', data.tasks ? `Array of ${data.tasks.length}` : 'undefined');
    if (data.tasks && data.tasks.length > 0) {
      console.log('First task:', JSON.stringify(data.tasks[0], null, 2));
    }
  }
  
  // Check tasks subcollection
  const tasksSnap = await db.collection('organizations')
    .doc(orgId)
    .collection('checklist_templates')
    .doc(templateId)
    .collection('tasks')
    .get();
  
  console.log('\nTasks subcollection size:', tasksSnap.size);
}

checkTemplate().catch(console.error);
