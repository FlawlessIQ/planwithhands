#!/usr/bin/env node

/**
 * Generate daily checklist from test template to verify photo required field transfer
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function generateTestDailyChecklist(orgId) {
  try {
    console.log(`🚀 Generating daily checklist from test template for org: ${orgId}`);
    
    const templateId = 'test-photo-template';
    const locationId = 'multi-loc'; // from earlier debug
    const shiftId = 'test-shift';
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD format
    
    console.log(`📅 Date: ${today}`);
    console.log(`📋 Template: ${templateId}`);
    console.log(`📍 Location: ${locationId}`);
    console.log(`🔄 Shift: ${shiftId}`);
    
    // First, create a test shift if it doesn't exist
    const shiftRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .doc(shiftId);
      
    await shiftRef.set({
      shiftName: 'Test Shift',
      locationIds: [locationId],
      checklistTemplateIds: [templateId],
      startTime: '09:00',
      endTime: '17:00',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    console.log(`✅ Created/updated test shift`);
    
    // Generate daily checklist ID
    const checklistId = `${orgId}_${locationId}_${shiftId}_${templateId}_${today}`;
    
    // Create daily checklist document
    const dailyChecklistRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .doc(checklistId);
    
    await dailyChecklistRef.set({
      id: checklistId,
      organizationId: orgId,
      locationId: locationId,
      shiftId: shiftId,
      checklistTemplateId: templateId,
      date: today,
      checklistName: 'Test Photo Required Checklist',
      templateName: 'Test Photo Required Template',
      totalItems: 0,
      completedItems: 0,
      isCompleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ Created daily checklist document: ${checklistId}`);
    
    // Get template tasks
    const templateTasksSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .doc(templateId)
      .collection('tasks')
      .orderBy('order')
      .get();
    
    console.log(`📝 Found ${templateTasksSnapshot.docs.length} template tasks to copy`);
    
    // Copy tasks from template to daily checklist
    const batch = db.batch();
    let taskCount = 0;
    
    for (const templateTaskDoc of templateTasksSnapshot.docs) {
      const templateTask = templateTaskDoc.data();
      const templateTaskId = templateTaskDoc.id;
      
      // Generate daily task ID (similar to the service logic)
      const dailyTaskId = `daily_${templateTaskId}_${checklistId}`;
      
      const dailyTaskRef = dailyChecklistRef.collection('tasks').doc(dailyTaskId);
      
      const dailyTaskData = {
        taskId: dailyTaskId,
        taskName: templateTask.taskName,
        photoRequired: templateTask.photoRequired || false, // This is the key field!
        completed: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        dueDate: admin.firestore.FieldValue.serverTimestamp(),
        isCarryForward: false,
        templateTaskId: templateTaskId,
        // Denormalized fields
        organizationId: orgId,
        locationId: locationId,
        dateString: today,
        shiftId: shiftId,
        checklistId: checklistId,
        checklistTemplateId: templateId,
        order: templateTask.order || 0,
      };
      
      batch.set(dailyTaskRef, dailyTaskData);
      
      console.log(`   📝 Will create daily task: "${templateTask.taskName}" | photoRequired: ${templateTask.photoRequired}`);
      taskCount++;
    }
    
    await batch.commit();
    
    // Update parent checklist with task count
    await dailyChecklistRef.update({
      totalItems: taskCount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ Created ${taskCount} daily tasks`);
    
    console.log('\n🔍 Verifying created daily checklist...');
    
    // Verify the daily tasks were created with photoRequired field
    const verifySnapshot = await dailyChecklistRef.collection('tasks').orderBy('order').get();
    console.log(`   Found ${verifySnapshot.docs.length} daily tasks:`);
    
    verifySnapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`     - "${data.taskName}" | photoRequired: ${data.photoRequired} | completed: ${data.completed}`);
      if (data.photoRequired) {
        console.log(`       ✨ PHOTO REQUIRED DAILY TASK CREATED!`);
      }
    });
    
    console.log(`\n✨ Daily checklist generated successfully!`);
    console.log(`📍 Location: ${locationId}`);
    console.log(`📅 Date: ${today}`);
    console.log(`🔗 Checklist ID: ${checklistId}`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  }
}

// Get org ID from command line
const orgId = process.argv[2];
if (!orgId) {
  console.error('Usage: node generate_test_daily_checklist.js <orgId>');
  process.exit(1);
}

generateTestDailyChecklist(orgId).then(() => process.exit(0));
