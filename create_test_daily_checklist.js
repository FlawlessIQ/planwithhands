const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
// Use the correct Firestore database (not the default)
db.settings({ databaseId: 'planwithhands' });

async function createTestDailyChecklist() {
  try {
    console.log('🔧 Creating test daily checklist for Hamilton Pork...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const targetDate = '2025-09-29'; // Yesterday, so the summary can find it
    
    // 1. Get a location and shift
    console.log('1. Getting location and shift information...');
    const locationsRef = db.collection('organizations').doc(orgId).collection('locations');
    const locations = await locationsRef.get();
    
    if (locations.empty) {
      console.log('❌ No locations found');
      return;
    }
    
    const location = locations.docs[0];
    const locationData = location.data();
    console.log(`Using location: ${locationData.name} (${location.id})`);
    
    // Get a shift
    const shiftsRef = db.collection('organizations').doc(orgId).collection('shifts');
    const shifts = await shiftsRef.get();
    
    if (shifts.empty) {
      console.log('❌ No shifts found');
      return;
    }
    
    const shift = shifts.docs[0];
    const shiftData = shift.data();
    console.log(`Using shift: ${shiftData.name || 'Unknown'} (${shift.id})`);
    
    // 2. Get a checklist template
    console.log('\n2. Getting checklist template...');
    const templatesRef = db.collection('organizations').doc(orgId).collection('checklist_templates');
    const templates = await templatesRef.get();
    
    if (templates.empty) {
      console.log('❌ No templates found');
      return;
    }
    
    const template = templates.docs[0];
    const templateData = template.data();
    console.log(`Using template: ${templateData.name || 'Unknown'} (${template.id})`);
    
    // 3. Create a daily checklist with some completed tasks
    console.log('\n3. Creating daily checklist...');
    
    const dailyChecklistData = {
      date: targetDate,
      locationId: location.id,
      locationName: locationData.name,
      shiftId: shift.id,
      shiftName: shiftData.name || 'Unknown Shift',
      templateId: template.id,
      templateName: templateData.name || 'Unknown Template',
      organizationId: orgId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'in_progress',
      completedTasks: 8, // Some completed tasks
      totalTasks: templateData.tasks?.length || 15,
      completedBy: 'sXAEgtodreSTrXU0DUpHKEoq0LC3', // John Gondevas' user ID
      notes: 'Test daily checklist for summary testing'
    };
    
    // Create the daily checklist document
    const dailyChecklistRef = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(location.id)
      .collection('daily_checklists')
      .doc();
    
    await dailyChecklistRef.set(dailyChecklistData);
    console.log(`✅ Created daily checklist: ${dailyChecklistRef.id}`);
    
    // 4. Create some tasks in the tasks subcollection
    console.log('\n4. Creating sample tasks...');
    
    const sampleTasks = [
      { name: 'Clean dining area', completed: true, completedAt: new Date(), completedBy: 'sXAEgtodreSTrXU0DUpHKEoq0LC3' },
      { name: 'Check inventory', completed: true, completedAt: new Date(), completedBy: 'sXAEgtodreSTrXU0DUpHKEoq0LC3' },
      { name: 'Set up tables', completed: true, completedAt: new Date(), completedBy: 'sXAEgtodreSTrXU0DUpHKEoq0LC3' },
      { name: 'Check equipment', completed: false },
      { name: 'Final inspection', completed: false }
    ];
    
    for (let i = 0; i < sampleTasks.length; i++) {
      const taskRef = dailyChecklistRef.collection('tasks').doc();
      await taskRef.set({
        ...sampleTasks[i],
        order: i + 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    console.log(`✅ Created ${sampleTasks.length} sample tasks`);
    
    // 5. Test the daily summary collection logic
    console.log('\n5. Testing if daily summary can now find this data...');
    
    const testQuery = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(location.id)
      .collection('daily_checklists')
      .where('date', '==', targetDate)
      .get();
    
    console.log(`✅ Query test: Found ${testQuery.size} daily checklists for ${targetDate}`);
    
    if (testQuery.size > 0) {
      const testDoc = testQuery.docs[0];
      const testData = testDoc.data();
      console.log(`   Template: ${testData.templateName}`);
      console.log(`   Completed: ${testData.completedTasks}/${testData.totalTasks} tasks`);
      
      // Check tasks subcollection
      const tasksQuery = await testDoc.ref.collection('tasks').get();
      console.log(`   Tasks subcollection: ${tasksQuery.size} tasks`);
    }
    
    console.log('\n🎉 Test daily checklist created successfully!');
    console.log('\n📋 NEXT STEPS:');
    console.log('==============');
    console.log('1. Wait for next daily summary run (or trigger manually)');
    console.log('2. The function should now find meaningful activity');
    console.log('3. Daily summary email should be sent to John Gondevas');
    console.log('\n💡 TIP: You can also create more daily checklists for today to test immediately');
    
  } catch (error) {
    console.error('❌ Error creating test daily checklist:', error);
  }
}

createTestDailyChecklist();