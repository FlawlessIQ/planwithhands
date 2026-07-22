const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function createTestData() {
  try {
    console.log('🔧 Creating test data for job type filtering...\n');
    
    const testOrgId = 'test-org-jobtype';
    const testLocationId = 'test-location-jobtype';
    
    // Create organization
    await db.collection('organizations').doc(testOrgId).set({
      name: 'Test Restaurant',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created organization:', testOrgId);
    
    // Create location
    await db.collection('organizations').doc(testOrgId).collection('locations').doc(testLocationId).set({
      name: 'Main Location',
      address: '123 Test St',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created location:', testLocationId);
    
    // Create kitchen staff user
    await db.collection('users').doc('test-user-kitchen').set({
      userId: 'test-user-kitchen',
      firstName: 'Test',
      lastName: 'Kitchen',
      email: 'kitchen@test.com',
      emailAddress: 'kitchen@test.com',
      userRole: 0, // General user
      organizationId: testOrgId,
      locationId: testLocationId,
      locationIds: [testLocationId],
      jobTypes: ['Kitchen Staff'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created kitchen staff user');
    
    // Create bartender user  
    await db.collection('users').doc('test-user-bartender').set({
      userId: 'test-user-bartender',
      firstName: 'Test',
      lastName: 'Bartender',
      email: 'bartender@test.com',
      emailAddress: 'bartender@test.com',
      userRole: 0, // General user
      organizationId: testOrgId,
      locationId: testLocationId,
      locationIds: [testLocationId],
      jobTypes: ['Bartender'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created bartender user');
    
    // Create kitchen checklist template
    await db.collection('organizations').doc(testOrgId).collection('checklistTemplates').doc('kitchen-template').set({
      name: 'Kitchen Opening Checklist',
      description: 'Opening tasks for kitchen staff',
      jobTypes: ['Kitchen Staff'],
      tasks: [
        { title: 'Check refrigerator temperatures', photoRequired: false },
        { title: 'Sanitize prep surfaces', photoRequired: true },
        { title: 'Set up cooking stations', photoRequired: false },
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created kitchen checklist template');
    
    // Create bartender checklist template
    await db.collection('organizations').doc(testOrgId).collection('checklistTemplates').doc('bar-template').set({
      name: 'Bar Opening Checklist', 
      description: 'Opening tasks for bartenders',
      jobTypes: ['Bartender'],
      tasks: [
        { title: 'Stock bar with clean glassware', photoRequired: false },
        { title: 'Check liquor inventory', photoRequired: false },
        { title: 'Prepare garnishes and mixers', photoRequired: true },
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created bartender checklist template');
    
    // Create shifts
    await db.collection('organizations').doc(testOrgId).collection('locations').doc(testLocationId).collection('shifts').doc('kitchen-shift').set({
      shiftName: 'Kitchen Opening',
      startTime: '08:00',
      endTime: '16:00',
      jobType: ['Kitchen Staff'],
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created kitchen shift');
    
    await db.collection('organizations').doc(testOrgId).collection('locations').doc(testLocationId).collection('shifts').doc('bar-shift').set({
      shiftName: 'Bar Opening',
      startTime: '16:00',
      endTime: '24:00',
      jobType: ['Bartender'],
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created bar shift');
    
    console.log('\n🎉 Test data created successfully!');
    console.log('📋 Now you can test job type filtering with:');
    console.log('   - Kitchen Staff User: test-user-kitchen (should only see kitchen checklists)');
    console.log('   - Bartender User: test-user-bartender (should only see bar checklists)');
    console.log(`   - Organization: ${testOrgId}`);
    console.log(`   - Location: ${testLocationId}`);
    
  } catch (error) {
    console.error('❌ Error creating test data:', error);
  }
}

createTestData().then(() => {
  console.log('\n✅ Setup complete');
  process.exit(0);
});