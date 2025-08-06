// Create test missed tasks for demonstration
const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to set up credentials)
// For testing purposes only - DO NOT commit credentials!

const db = admin.firestore();

async function createTestMissedTasks() {
  const organizationId = 'vnE0olvi1Tswjtdb19MI';
  const locationId = 'rGAc76DxU9TQhcJy21h0';
  const shiftId = 'test_shift';
  const templateId = 'test_template';
  const today = '2025-08-05';
  const yesterday = '2025-08-04';
  
  const checklistId = `${organizationId}_${locationId}_${shiftId}_${templateId}_${today}`;
  
  const testMissedTasks = [
    {
      taskId: 'missed_task_1',
      title: 'Check inventory levels',
      description: 'Check and record all inventory levels',
      completed: false,
      isCompleted: false,
      isCarryForward: true,
      originalDate: admin.firestore.Timestamp.fromDate(new Date(yesterday)),
      originalChecklistId: `${organizationId}_${locationId}_${shiftId}_${templateId}_${yesterday}`,
      originalTaskId: 'original_task_1',
      carriedIntoDate: admin.firestore.Timestamp.fromDate(new Date(today)),
      photoRequired: false,
      completedBy: null,
      completedAt: null,
      proofImageUrl: null,
      notes: null,
      notCompletedReason: null
    },
    {
      taskId: 'missed_task_2', 
      title: 'Clean equipment',
      description: 'Deep clean all kitchen equipment',
      completed: false,
      isCompleted: false,
      isCarryForward: true,
      originalDate: admin.firestore.Timestamp.fromDate(new Date(yesterday)),
      originalChecklistId: `${organizationId}_${locationId}_${shiftId}_${templateId}_${yesterday}`,
      originalTaskId: 'original_task_2',
      carriedIntoDate: admin.firestore.Timestamp.fromDate(new Date(today)),
      photoRequired: true,
      completedBy: null,
      completedAt: null,
      proofImageUrl: null,
      notes: null,
      notCompletedReason: null
    }
  ];

  const checklistDoc = {
    id: checklistId,
    organizationId: organizationId,
    locationId: locationId,
    shiftId: shiftId,
    templateId: templateId,
    templateName: 'Test Shift Template',
    date: today,
    tasks: testMissedTasks,
    isCompleted: false,
    completedBy: null,
    completedAt: null,
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now()
  };

  try {
    await db
      .collection('organizations')
      .doc(organizationId)
      .collection('locations')
      .doc(locationId)  
      .collection('daily_checklists')
      .doc(checklistId)
      .set(checklistDoc);
      
    console.log('Test missed tasks created successfully!');
    console.log('Checklist ID:', checklistId);
    console.log('Tasks created:', testMissedTasks.length);
  } catch (error) {
    console.error('Error creating test missed tasks:', error);
  }
}

// Uncomment to run (you'll need to set up Firebase Admin credentials first)
// createTestMissedTasks();

module.exports = { createTestMissedTasks };
