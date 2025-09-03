#!/usr/bin/env node

/**
 * Create test checklist template with photo required tasks
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function createTestTemplate(orgId) {
  try {
    console.log(`🚀 Creating test template with photo required tasks for org: ${orgId}`);
    
    const templateId = 'test-photo-template';
    const templateRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .doc(templateId);
    
    // Create template document
    await templateRef.set({
      name: 'Test Photo Required Template',
      description: 'Test template with photo required tasks',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ Created template document: ${templateId}`);
    
    // Create tasks subcollection
    const tasksToCreate = [
      {
        id: 'task1',
        taskName: 'Regular Task (no photo)',
        photoRequired: false,
        order: 0,
      },
      {
        id: 'task2', 
        taskName: 'Photo Required Task',
        photoRequired: true,
        order: 1,
      },
      {
        id: 'task3',
        taskName: 'Another Photo Task', 
        photoRequired: true,
        order: 2,
      }
    ];
    
    const batch = db.batch();
    
    for (const task of tasksToCreate) {
      const taskRef = templateRef.collection('tasks').doc(task.id);
      batch.set(taskRef, {
        taskId: task.id,
        taskName: task.taskName,
        photoRequired: task.photoRequired,
        order: task.order,
        organizationId: orgId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`   📝 Will create task: "${task.taskName}" | photoRequired: ${task.photoRequired}`);
    }
    
    await batch.commit();
    console.log(`✅ Created ${tasksToCreate.length} tasks in subcollection`);
    
    console.log('\n🔍 Verifying created data...');
    
    // Verify the data was saved correctly
    const verifySnapshot = await templateRef.collection('tasks').get();
    console.log(`   Found ${verifySnapshot.docs.length} tasks:`);
    
    verifySnapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`     - "${data.taskName}" | photoRequired: ${data.photoRequired} | id: ${doc.id}`);
    });
    
    console.log(`\n✨ Test template created successfully! Template ID: ${templateId}`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Get org ID from command line
const orgId = process.argv[2];
if (!orgId) {
  console.error('Usage: node create_test_template.js <orgId>');
  process.exit(1);
}

createTestTemplate(orgId).then(() => process.exit(0));
