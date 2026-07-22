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

async function investigateNoActivity() {
  try {
    console.log('🔍 Investigating why Hamilton Pork shows "No meaningful activity"...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const targetDate = '2025-09-30';  // The date from the logs
    
    console.log(`Checking activity for org ${orgId} on ${targetDate}`);
    
    // 1. Check if there are any daily checklists for this date
    console.log('\n1. Checking daily checklists...');
    const dailyChecklistsRef = db.collection('organizations').doc(orgId).collection('dailyChecklists');
    const dateQuery = await dailyChecklistsRef.where('date', '==', targetDate).get();
    
    console.log(`Found ${dateQuery.size} daily checklists for ${targetDate}`);
    
    if (dateQuery.size > 0) {
      let totalTasks = 0;
      let completedTasks = 0;
      
      dateQuery.forEach(doc => {
        const data = doc.data();
        console.log(`   Checklist: ${data.templateName || 'Unknown'} at ${data.locationName || 'Unknown location'}`);
        console.log(`   Tasks: ${data.tasks?.length || 0}, Completed: ${data.completedTasks || 0}`);
        
        totalTasks += data.tasks?.length || 0;
        completedTasks += data.completedTasks || 0;
      });
      
      console.log(`\nTotal: ${totalTasks} tasks, ${completedTasks} completed (${totalTasks > 0 ? Math.round(completedTasks/totalTasks*100) : 0}%)`);
    }
    
    // 2. Check if the function is looking in the right collection structure
    console.log('\n2. Checking collection structure...');
    
    // Check if there are any collections under the organization
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    console.log(`Organization: ${orgDoc.data().name}`);
    
    // List all subcollections
    console.log('\nSubcollections under organization:');
    const collections = await orgDoc.ref.listCollections();
    collections.forEach(collection => {
      console.log(`   - ${collection.id}`);
    });
    
    // 3. Check for activity on nearby dates (maybe timezone issue?)
    console.log('\n3. Checking nearby dates for activity...');
    const dates = ['2025-09-29', '2025-09-30', '2025-10-01'];
    
    for (const date of dates) {
      const dateQuery = await dailyChecklistsRef.where('date', '==', date).get();
      console.log(`   ${date}: ${dateQuery.size} daily checklists`);
      
      if (dateQuery.size > 0) {
        let dayTotalTasks = 0;
        let dayCompletedTasks = 0;
        
        dateQuery.forEach(doc => {
          const data = doc.data();
          dayTotalTasks += data.tasks?.length || 0;
          dayCompletedTasks += data.completedTasks || 0;
        });
        
        if (dayTotalTasks > 0) {
          console.log(`     Activity found: ${dayTotalTasks} tasks, ${dayCompletedTasks} completed`);
        }
      }
    }
    
    // 4. Check if the issue is with the date format or timezone
    console.log('\n4. Checking date format and timezone issues...');
    
    // Check for documents with different date formats
    const allDailyChecklists = await dailyChecklistsRef.limit(10).get();
    console.log('\nSample daily checklist date formats:');
    allDailyChecklists.forEach(doc => {
      const data = doc.data();
      console.log(`   Document ID: ${doc.id}`);
      console.log(`   Date field: ${data.date} (type: ${typeof data.date})`);
      if (data.createdAt) {
        console.log(`   Created: ${new Date(data.createdAt._seconds * 1000).toISOString()}`);
      }
      console.log('');
    });
    
    // 5. Check the organization's daily summary function settings
    console.log('5. Checking daily summary function logic expectations...');
    const orgData = orgDoc.data();
    
    console.log(`   Timezone: ${orgData.timezone}`);
    console.log(`   Daily summary time: ${orgData.dailySummarySettings.hour}:${orgData.dailySummarySettings.minute.toString().padStart(2, '0')}`);
    
    // Calculate what date the function should be looking for based on timezone
    const { DateTime } = require('luxon');
    const orgTimezone = orgData.timezone || "America/New_York";
    
    // At 1:00 UTC on Sept 30, what date is it in the org's timezone?
    const functionRunTime = DateTime.fromISO('2025-09-30T01:00:00Z');
    const orgLocalTime = functionRunTime.setZone(orgTimezone);
    
    console.log(`\nFunction ran at: ${functionRunTime.toISO()} UTC`);
    console.log(`Organization local time: ${orgLocalTime.toISO()}`);
    console.log(`Local date: ${orgLocalTime.toFormat('yyyy-MM-dd')}`);
    
    // The function might be looking for the previous day's activity
    const expectedDate = orgLocalTime.minus({ days: 1 }).toFormat('yyyy-MM-dd');
    console.log(`Expected summary date (previous day): ${expectedDate}`);
    
    // Check that date
    const expectedDateQuery = await dailyChecklistsRef.where('date', '==', expectedDate).get();
    console.log(`Checklists for expected date ${expectedDate}: ${expectedDateQuery.size}`);
    
    if (expectedDateQuery.size > 0) {
      let expectedTotalTasks = 0;
      let expectedCompletedTasks = 0;
      
      expectedDateQuery.forEach(doc => {
        const data = doc.data();
        expectedTotalTasks += data.tasks?.length || 0;
        expectedCompletedTasks += data.completedTasks || 0;
      });
      
      console.log(`   Activity on ${expectedDate}: ${expectedTotalTasks} tasks, ${expectedCompletedTasks} completed`);
      
      if (expectedTotalTasks > 0) {
        console.log('\n🎯 FOUND THE ISSUE: Function should be looking at previous day\'s activity!');
      }
    }
    
    console.log('\n📋 DIAGNOSIS:');
    console.log('=============');
    if (expectedDateQuery.size > 0) {
      console.log('✅ There IS activity data available');
      console.log('❌ Function is looking at wrong date (timezone/calendar logic issue)');
      console.log('\n🔧 SOLUTION: Fix the date calculation in the daily summary function');
    } else {
      console.log('❌ No daily checklist activity found for recent dates');
      console.log('   This could mean:');
      console.log('   1. No checklists were completed on those days');
      console.log('   2. Data is stored in a different location/format');
      console.log('   3. Date format mismatch');
    }
    
  } catch (error) {
    console.error('❌ Error investigating no activity:', error);
  }
}

investigateNoActivity();