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

async function findActualDataLocation() {
  try {
    console.log('🔍 Finding where daily checklist data is actually stored...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // 1. Check the locations collection for daily checklists
    console.log('1. Checking locations collection for daily checklists...');
    const locationsRef = db.collection('organizations').doc(orgId).collection('locations');
    const locations = await locationsRef.get();
    
    console.log(`Found ${locations.size} locations`);
    
    for (const locationDoc of locations.docs) {
      const locationData = locationDoc.data();
      console.log(`\nLocation: ${locationData.name} (${locationDoc.id})`);
      
      // Check for dailyChecklists subcollection under this location
      const locationDailyChecklists = await locationDoc.ref.collection('dailyChecklists').limit(5).get();
      console.log(`   Daily checklists: ${locationDailyChecklists.size}`);
      
      if (locationDailyChecklists.size > 0) {
        console.log('   📍 FOUND daily checklists in location!');
        locationDailyChecklists.forEach(doc => {
          const data = doc.data();
          console.log(`      - ${data.templateName || 'Unknown'} on ${data.date}`);
          console.log(`        Tasks: ${data.tasks?.length || 0}, Completed: ${data.completedTasks || 0}`);
        });
      }
    }
    
    // 2. Check shifts collection for daily checklists
    console.log('\n2. Checking shifts collection...');
    const shiftsRef = db.collection('organizations').doc(orgId).collection('shifts');
    const shifts = await shiftsRef.get();
    
    console.log(`Found ${shifts.size} shifts`);
    
    for (const shiftDoc of shifts.docs) {
      const shiftData = shiftDoc.data();
      console.log(`\nShift: ${shiftData.name || 'Unknown'} (${shiftDoc.id})`);
      
      // Check for dailyChecklists subcollection under this shift
      const shiftDailyChecklists = await shiftDoc.ref.collection('dailyChecklists').limit(5).get();
      console.log(`   Daily checklists: ${shiftDailyChecklists.size}`);
      
      if (shiftDailyChecklists.size > 0) {
        console.log('   📍 FOUND daily checklists in shift!');
        shiftDailyChecklists.forEach(doc => {
          const data = doc.data();
          console.log(`      - ${data.templateName || 'Unknown'} on ${data.date}`);
          console.log(`        Tasks: ${data.tasks?.length || 0}, Completed: ${data.completedTasks || 0}`);
        });
      }
    }
    
    // 3. Check for a top-level dailyChecklists collection
    console.log('\n3. Checking top-level dailyChecklists collection...');
    const topLevelDailyChecklists = await db.collection('dailyChecklists')
      .where('organizationId', '==', orgId)
      .limit(10)
      .get();
    
    console.log(`Found ${topLevelDailyChecklists.size} daily checklists at top level`);
    
    if (topLevelDailyChecklists.size > 0) {
      console.log('   📍 FOUND daily checklists at top level!');
      topLevelDailyChecklists.forEach(doc => {
        const data = doc.data();
        console.log(`      - ${data.templateName || 'Unknown'} on ${data.date}`);
        console.log(`        Location: ${data.locationName || 'Unknown'}`);
        console.log(`        Tasks: ${data.tasks?.length || 0}, Completed: ${data.completedTasks || 0}`);
      });
    }
    
    // 4. Check what the daily summary function code actually expects
    console.log('\n4. Looking at Cloud Function expectations...');
    console.log('Let me check the scheduledDailySummary function source to see what collection it queries...');
    
    // Based on what we saw in the investigation, let me check different possible structures
    console.log('\n5. Checking alternative collection structures...');
    
    // Try organizations/{orgId}/daily_summary_by_organization
    const summaryByOrg = await db.collection('organizations').doc(orgId)
      .collection('daily_summary_by_organization').limit(5).get();
    console.log(`   daily_summary_by_organization: ${summaryByOrg.size} documents`);
    
    // Try organizations/{orgId}/daily_summary_by_location  
    const summaryByLocation = await db.collection('organizations').doc(orgId)
      .collection('daily_summary_by_location').limit(5).get();
    console.log(`   daily_summary_by_location: ${summaryByLocation.size} documents`);
    
    // Try organizations/{orgId}/daily_summary_by_shift
    const summaryByShift = await db.collection('organizations').doc(orgId)
      .collection('daily_summary_by_shift').limit(5).get();
    console.log(`   daily_summary_by_shift: ${summaryByShift.size} documents`);
    
    // 6. Check if there are any documents that might contain checklist completion data
    console.log('\n6. Checking for any activity data in recent days...');
    
    // Look for any collections that might contain task completion data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const collections = await orgDoc.ref.listCollections();
    
    for (const collection of collections) {
      if (collection.id.includes('daily') || collection.id.includes('summary') || collection.id.includes('checklist')) {
        const docs = await collection.limit(3).get();
        if (docs.size > 0) {
          console.log(`\n   Collection: ${collection.id} (${docs.size} docs)`);
          docs.forEach(doc => {
            const data = doc.data();
            console.log(`      Doc: ${doc.id}`);
            if (data.date) console.log(`      Date: ${data.date}`);
            if (data.tasks) console.log(`      Tasks: ${data.tasks.length}`);
            if (data.completedTasks) console.log(`      Completed: ${data.completedTasks}`);
          });
        }
      }
    }
    
    console.log('\n📋 NEXT STEPS:');
    console.log('==============');
    console.log('1. Identify where daily checklist data is actually stored');
    console.log('2. Verify the Cloud Function is querying the correct collection');
    console.log('3. Ensure data exists for the dates being queried');
    console.log('4. Fix the function to look in the correct location');
    
  } catch (error) {
    console.error('❌ Error finding actual data location:', error);
  }
}

findActualDataLocation();