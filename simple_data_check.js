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

async function simpleDataCheck() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  console.log(`🔍 Simple data check for organization ${orgId}`);
  console.log('=' .repeat(60));

  try {
    // Get organization details
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    console.log(`Organization: ${orgData.name}`);

    // Get locations
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    const locations = locationsSnapshot.docs.map(doc => ({
      id: doc.id,
      name: doc.data().name || `Location ${doc.id.substring(0, 8)}`,
      address: doc.data().address
    }));
    
    console.log(`\nLocations (${locations.length}):`);
    locations.forEach(loc => {
      console.log(`  - ${loc.name}: ${loc.address}`);
    });

    // Check users and their roles
    console.log('\n👥 Users:');
    const usersSnapshot = await db.collection('organizations').doc(orgId).collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('  ❌ No users found');
    } else {
      console.log(`  Found ${usersSnapshot.docs.length} users:`);
      usersSnapshot.docs.forEach(doc => {
        const userData = doc.data();
        const roles = userData.roles || [];
        console.log(`    - ${userData.name || 'Unnamed'} (${userData.email})`);
        console.log(`      Roles: ${roles.join(', ') || 'None'}`);
        console.log(`      Active: ${userData.isActive !== false}`);
      });
    }

    // Check specific recent dates without ordering
    console.log('\n📅 Checking Recent Dates:');
    const datesToCheck = [];
    
    for (let i = 0; i < 10; i++) {
      const checkDate = new Date();
      checkDate.setDate(checkDate.getDate() - i);
      const dateStr = checkDate.toISOString().split('T')[0];
      datesToCheck.push(dateStr);
    }
    
    console.log(`Checking: ${datesToCheck.slice(0, 5).join(', ')} ...`);
    
    let foundData = false;
    
    for (const dateStr of datesToCheck) {
      // Check new structure first
      const newStructureRef = db.collection('organizations').doc(orgId).collection('dailyChecklists').doc(dateStr);
      const newStructureDoc = await newStructureRef.get();
      
      if (newStructureDoc.exists) {
        console.log(`  ✅ ${dateStr}: Found in new structure`);
        foundData = true;
        
        // Check locations under this date
        const locationsRef = newStructureDoc.ref.collection('locations');
        const locationsSnapshot = await locationsRef.get();
        
        console.log(`    Locations with data: ${locationsSnapshot.docs.length}`);
        
        let dateTaskCount = 0;
        for (const locationDoc of locationsSnapshot.docs) {
          const checklistsRef = locationDoc.ref.collection('checklists');
          const checklistsSnapshot = await checklistsRef.get();
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            if (checklistData.tasks) {
              dateTaskCount += Object.keys(checklistData.tasks).length;
            }
          }
        }
        console.log(`    Total tasks: ${dateTaskCount}`);
        continue;
      }
      
      // Check legacy structure for each location
      let foundLegacyForDate = false;
      for (const location of locations) {
        const legacyRef = db.collection('organizations').doc(orgId)
          .collection('locations').doc(location.id)
          .collection('dailyChecklists').doc(dateStr);
        
        const legacyDoc = await legacyRef.get();
        if (legacyDoc.exists) {
          if (!foundLegacyForDate) {
            console.log(`  ✅ ${dateStr}: Found in legacy structure`);
            foundLegacyForDate = true;
            foundData = true;
          }
          
          const data = legacyDoc.data();
          const taskCount = data.tasks ? Object.keys(data.tasks).length : 0;
          console.log(`    ${location.name}: ${taskCount} tasks`);
        }
      }
      
      if (!newStructureDoc.exists && !foundLegacyForDate) {
        console.log(`  ❌ ${dateStr}: No data found`);
      }
    }
    
    if (!foundData) {
      console.log('\n🚨 No checklist data found in the last 10 days');
    }

    // Final analysis
    console.log('\n💡 Analysis:');
    
    const adminUsers = usersSnapshot.docs.filter(doc => {
      const userData = doc.data();
      return userData.roles && userData.roles.includes('admin');
    });
    
    if (usersSnapshot.empty) {
      console.log('  🚨 CRITICAL: No users in organization');
      console.log('     - This organization has no users at all');
      console.log('     - Daily summaries cannot be sent');
      console.log('     - No one can access the app for this org');
    } else if (adminUsers.length === 0) {
      console.log('  🚨 CRITICAL: No admin users found');
      console.log('     - Daily summaries are only sent to admin users');
      console.log('     - This explains why summaries are not being sent');
      console.log('     - Need to assign admin role to at least one user');
    } else {
      console.log(`  ✅ Found ${adminUsers.length} admin users - daily summaries should be sent to them`);
    }
    
    if (!foundData) {
      console.log('  🚨 CRITICAL: No recent checklist data');
      console.log('     - Staff may not be using the app');
      console.log('     - Data collection may be broken');
      console.log('     - Daily summaries will be empty even if sent');
    } else {
      console.log('  ✅ Found recent checklist data - content should be available for summaries');
    }

    // Specific recommendations
    console.log('\n🔧 Immediate Actions Needed:');
    if (usersSnapshot.empty) {
      console.log('  1. Add users to this organization');
      console.log('  2. Assign admin role to management users');
      console.log('  3. Ensure staff have access to submit checklists');
    } else if (adminUsers.length === 0) {
      console.log('  1. Update existing users to have admin role');
      console.log('  2. Test daily summary sending after adding admin role');
    }
    
    if (!foundData) {
      console.log('  3. Investigate why no checklists are being submitted');
      console.log('  4. Check if staff are trained on the app');
      console.log('  5. Verify checklist templates are set up correctly');
    }

  } catch (error) {
    console.error('❌ Error in data check:', error);
  }
}

// Run the check
simpleDataCheck().then(() => {
  console.log('\n✅ Check complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});