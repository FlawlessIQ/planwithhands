const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

// Create a Firestore instance that uses the planwithhands database
const db = new Firestore({
  projectId: "plan-with-hands",
  databaseId: "planwithhands",
});

async function searchRecentData() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  console.log(`🔍 Searching for recent checklist data for organization ${orgId}`);
  console.log('=' .repeat(80));

  try {
    // Get organization details again
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    console.log(`Organization: ${orgData.name}`);

    // Get locations with better details
    console.log('\n📍 Location Details:');
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    
    const locations = [];
    for (const doc of locationsSnapshot.docs) {
      const locationData = doc.data();
      locations.push({
        id: doc.id,
        name: locationData.name || `Location ${doc.id.substring(0, 8)}`,
        address: locationData.address,
        data: locationData
      });
      
      console.log(`  📍 ${locationData.name || 'Unnamed'} (${doc.id})`);
      console.log(`     Address: ${locationData.address || 'No address'}`);
      console.log(`     Created: ${locationData.createdAt?.toDate().toLocaleDateString() || 'Unknown'}`);
    }

    // Check for users with different roles
    console.log('\n👥 All Users:');
    const usersSnapshot = await db.collection('organizations').doc(orgId).collection('users').get();
    
    console.log(`  Total users: ${usersSnapshot.docs.length}`);
    usersSnapshot.docs.forEach(doc => {
      const userData = doc.data();
      console.log(`    - ${userData.name || 'Unnamed'} (${userData.email})`);
      console.log(`      Roles: ${userData.roles ? userData.roles.join(', ') : 'None'}`);
      console.log(`      Active: ${userData.isActive !== false ? 'Yes' : 'No'}`);
    });

    // Search for ANY dailyChecklists data structure
    console.log('\n📋 Searching for Daily Checklists:');
    
    // Check new structure: organizations/{orgId}/dailyChecklists/
    const dailyChecklistsRef = db.collection('organizations').doc(orgId).collection('dailyChecklists');
    const dailyChecklistsSnapshot = await dailyChecklistsRef.limit(10).get();
    
    console.log(`\n🗂️ New Structure (dailyChecklists collection):`);
    if (dailyChecklistsSnapshot.empty) {
      console.log('  No documents found');
    } else {
      console.log(`  Found ${dailyChecklistsSnapshot.docs.length} date documents:`);
      dailyChecklistsSnapshot.docs.forEach(doc => {
        console.log(`    📅 ${doc.id} (${new Date(doc.id).toDateString()})`);
      });
      
      // Check the most recent one for structure
      const recentDoc = dailyChecklistsSnapshot.docs[0];
      console.log(`\n  📋 Examining structure of ${recentDoc.id}:`);
      
      const locationsInDateRef = recentDoc.ref.collection('locations');
      const locationsInDateSnapshot = await locationsInDateRef.get();
      
      if (locationsInDateSnapshot.empty) {
        console.log('    No locations subcollection');
        
        // Check if data is directly in the date document
        const dateData = recentDoc.data();
        console.log(`    Direct data keys: ${Object.keys(dateData).join(', ')}`);
      } else {
        console.log(`    Found ${locationsInDateSnapshot.docs.length} locations:`);
        
        for (const locationDoc of locationsInDateSnapshot.docs) {
          console.log(`      📍 Location: ${locationDoc.id}`);
          
          const checklistsRef = locationDoc.ref.collection('checklists');
          const checklistsSnapshot = await checklistsRef.get();
          
          if (checklistsSnapshot.empty) {
            console.log('        No checklists subcollection');
            const locationData = locationDoc.data();
            console.log(`        Direct data keys: ${Object.keys(locationData).join(', ')}`);
          } else {
            console.log(`        Found ${checklistsSnapshot.docs.length} checklists`);
            
            // Examine first checklist
            const firstChecklist = checklistsSnapshot.docs[0];
            const checklistData = firstChecklist.data();
            console.log(`        Sample checklist keys: ${Object.keys(checklistData).join(', ')}`);
            
            if (checklistData.tasks) {
              const tasks = Object.values(checklistData.tasks);
              console.log(`        Tasks: ${tasks.length}`);
              if (tasks.length > 0) {
                const sampleTask = tasks[0];
                console.log(`        Sample task: ${sampleTask.title || 'Untitled'} (${sampleTask.status || 'no status'})`);
              }
            }
          }
        }
      }
    }

    // Check legacy structure for each location
    console.log(`\n🗃️ Legacy Structure (locations/{id}/dailyChecklists):`);
    for (const location of locations) {
      console.log(`\n  📍 ${location.name}:`);
      
      const legacyDailyChecklistsRef = db.collection('organizations').doc(orgId)
        .collection('locations').doc(location.id)
        .collection('dailyChecklists');
      
      const legacySnapshot = await legacyDailyChecklistsRef.orderBy('__name__', 'desc').limit(5).get();
      
      if (legacySnapshot.empty) {
        console.log('    No legacy daily checklists found');
      } else {
        console.log(`    Found ${legacySnapshot.docs.length} recent dates:`);
        legacySnapshot.docs.forEach(doc => {
          const data = doc.data();
          const tasksCount = data.tasks ? Object.keys(data.tasks).length : 0;
          console.log(`      📅 ${doc.id}: ${tasksCount} tasks`);
        });
        
        // Examine most recent
        const recentLegacy = legacySnapshot.docs[0];
        const recentData = recentLegacy.data();
        console.log(`    Most recent (${recentLegacy.id}) structure:`);
        console.log(`      Keys: ${Object.keys(recentData).join(', ')}`);
        
        if (recentData.tasks) {
          const tasks = Object.values(recentData.tasks);
          const completed = tasks.filter(t => t.status === 'completed').length;
          const missed = tasks.filter(t => t.status === 'missed').length;
          console.log(`      Tasks: ${tasks.length} total, ${completed} completed, ${missed} missed`);
        }
      }
    }

    // Check for ANY documents in the last week
    console.log('\n📅 Recent Activity Check:');
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    const recentDates = [];
    for (let i = 0; i < 7; i++) {
      const checkDate = new Date();
      checkDate.setDate(checkDate.getDate() - i);
      const dateStr = checkDate.toISOString().split('T')[0];
      recentDates.push(dateStr);
    }
    
    console.log(`Checking dates: ${recentDates.join(', ')}`);
    
    let foundAnyData = false;
    
    for (const dateStr of recentDates) {
      // Check new structure
      const dateDocRef = db.collection('organizations').doc(orgId).collection('dailyChecklists').doc(dateStr);
      const dateDoc = await dateDocRef.get();
      
      if (dateDoc.exists) {
        console.log(`  ✅ Found data for ${dateStr} in new structure`);
        foundAnyData = true;
        
        // Quick count
        const locationsRef = dateDoc.ref.collection('locations');
        const locationsSnapshot = await locationsRef.get();
        
        let totalTasksForDate = 0;
        for (const locationDoc of locationsSnapshot.docs) {
          const checklistsRef = locationDoc.ref.collection('checklists');
          const checklistsSnapshot = await checklistsRef.get();
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            if (checklistData.tasks) {
              totalTasksForDate += Object.keys(checklistData.tasks).length;
            }
          }
        }
        console.log(`    Total tasks: ${totalTasksForDate}`);
        
        continue; // Skip legacy check if new structure found
      }
      
      // Check legacy structure
      for (const location of locations) {
        const legacyDocRef = db.collection('organizations').doc(orgId)
          .collection('locations').doc(location.id)
          .collection('dailyChecklists').doc(dateStr);
        
        const legacyDoc = await legacyDocRef.get();
        if (legacyDoc.exists) {
          const data = legacyDoc.data();
          const tasksCount = data.tasks ? Object.keys(data.tasks).length : 0;
          console.log(`  ✅ Found data for ${dateStr} in legacy structure (${location.name}): ${tasksCount} tasks`);
          foundAnyData = true;
          break; // Found one, that's enough for this date
        }
      }
    }
    
    if (!foundAnyData) {
      console.log('  ❌ No checklist data found in the last 7 days');
    }

    console.log('\n💡 Summary of Findings:');
    if (usersSnapshot.docs.length === 0) {
      console.log('  🚨 Critical: No users found in organization');
    } else {
      const adminUsers = usersSnapshot.docs.filter(doc => {
        const userData = doc.data();
        return userData.roles && userData.roles.includes('admin');
      });
      
      if (adminUsers.length === 0) {
        console.log('  🚨 Critical: No admin users found - this explains why daily summaries are not being sent');
        console.log('    Daily summaries are only sent to users with admin role');
      } else {
        console.log(`  ✅ Found ${adminUsers.length} admin users`);
      }
    }
    
    if (!foundAnyData) {
      console.log('  🚨 Critical: No recent checklist data found');
      console.log('    Possible reasons:');
      console.log('    - Staff are not submitting daily checklists');
      console.log('    - App is not being used regularly');
      console.log('    - Technical issue with data collection');
    }

  } catch (error) {
    console.error('❌ Error searching data:', error);
  }
}

// Run the search
searchRecentData().then(() => {
  console.log('\n✅ Search complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});