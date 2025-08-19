const admin = require('firebase-admin');
const serviceAccount = require('./functions/firebase_config.js');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://plan-with-hands.firebaseio.com'
});

const db = admin.firestore();

async function createTestMissedTask() {
  console.log('Creating test missed task for yesterday...');
  
  const yesterday = '2025-08-13';
  const orgId = 'vnE0olvi1Tswjtdb19MI';
  const locationId = 'rGAc76DxU9TQhcJy21h0';
  const shiftId = 'AiX5sfrfkIqdS5XutZaR'; // Opening Bar shift
  const checklistId = orgId + '_' + locationId + '_' + shiftId + '_E2XiLWhTcyO2uuq1Lq6O_' + yesterday;
  
  // Create test task
  const taskData = {
    title: 'Test Missed Task from Yesterday',
    description: 'This task was not completed yesterday',
    completed: false,
    dateString: yesterday,
    organizationId: orgId,
    locationId: locationId,
    shiftId: shiftId,
    shiftName: 'Opening Bar',
    checklistId: checklistId,
    jobType: 'Bartender',
    assignedUserId: 'GSMxCCzSnEbqhy1myX5PhBopgIU2',
    order: 1,
    isCarryForward: false,
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now()
  };
  
  // Add to subcollection
  const taskRef = db.collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .doc(checklistId)
    .collection('tasks')
    .doc();
    
  await taskRef.set(taskData);
  console.log('Test missed task created successfully with ID:', taskRef.id);
  
  // Also create the parent checklist if it doesn't exist
  const checklistRef = db.collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .doc(checklistId);
    
  const checklistDoc = await checklistRef.get();
  if (!checklistDoc.exists) {
    await checklistRef.set({
      date: yesterday,
      shiftId: shiftId,
      shiftName: 'Opening Bar',
      templateId: 'E2XiLWhTcyO2uuq1Lq6O',
      organizationId: orgId,
      locationId: locationId,
      isCompleted: false,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now()
    });
    console.log('Parent checklist created:', checklistId);
  }
  
  process.exit(0);
}

createTestMissedTask().catch(console.error);
