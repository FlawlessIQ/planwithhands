const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com'
  });
}

const db = admin.firestore();
// Make sure we're using the planwithhands database, not the default
db.settings({
  databaseId: 'planwithhands'
});

async function debugChecklistLocationIssue() {
  console.log('🔍 Investigating checklist location issue for org: FErQ4pkcrCovJ7T6L13M');
  console.log('=' * 60);

  const orgId = 'FErQ4pkcrCovJ7T6L13M';

  try {
    // 1. Get organization info
    console.log('\n📋 Organization Info:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log(`Name: ${orgData.name || orgData.organizationName || 'Unknown'}`);
      console.log(`Business Type: ${orgData.businessType || 'Unknown'}`);
      console.log(`Created: ${orgData.createdAt?.toDate() || 'Unknown'}`);
    }

    // 2. Get all locations for this org
    console.log('\n🏢 Locations:');
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    const locations = {};
    
    locationsSnapshot.forEach(doc => {
      const data = doc.data();
      locations[doc.id] = data;
      console.log(`  ${doc.id}: ${data.name || 'Unnamed'}`);
    });

    // 3. Get all shifts for this org
    console.log('\n⏰ Shifts:');
    const shiftsSnapshot = await db.collection('organizations').doc(orgId).collection('shifts').get();
    const shifts = {};
    
    shiftsSnapshot.forEach(doc => {
      const data = doc.data();
      shifts[doc.id] = data;
      const locationName = locations[data.locationIds?.[0]]?.name || 'Unknown Location';
      console.log(`  ${doc.id}: ${data._shiftName || data.shiftName || 'Unnamed'} (${locationName})`);
      console.log(`    Location IDs: ${JSON.stringify(data.locationIds || [])}`);
      console.log(`    Template IDs: ${JSON.stringify(data.checklistTemplateIds || [])}`);
    });

    // 4. Look for today's checklists and their assignments
    console.log('\n📝 Today\'s Checklists:');
    const today = new Date();
    const todayString = today.toISOString().split('T')[0]; // YYYY-MM-DD
    
    // Check both collections that might contain today's checklists
    const todayCollections = [
      `organizations/${orgId}/today`,
      `organizations/${orgId}/todayChecklists`
    ];

    for (const collectionPath of todayCollections) {
      try {
        const todaySnapshot = await db.collection(collectionPath).get();
        if (!todaySnapshot.empty) {
          console.log(`\n  From ${collectionPath}:`);
          todaySnapshot.forEach(doc => {
            const data = doc.data();
            const locationName = locations[data.locationIds?.[0]]?.name || 'Unknown Location';
            const shiftName = shifts[data.assignedShiftId]?._shiftName || shifts[data.assignedShiftId]?.shiftName || 'Unknown Shift';
            
            console.log(`    ${doc.id}: ${data.name || 'Unnamed'}`);
            console.log(`      Location IDs: ${JSON.stringify(data.locationIds || [])}`);
            console.log(`      Assigned Shift: ${data.assignedShiftId || 'None'} (${shiftName})`);
            console.log(`      Template ID: ${data.templateId || 'None'}`);
            console.log(`      Job Type: ${data.jobType || 'None'}`);
            
            // Check if this is the problematic checklist
            if (data.name && data.name.toLowerCase().includes('server') && data.name.toLowerCase().includes('pre dinner')) {
              console.log(`      🚨 POTENTIAL ISSUE: This appears to be the "C Server - Pre Dinner" checklist`);
              console.log(`      🚨 Expected Location: Chickies, Actual Location IDs: ${JSON.stringify(data.locationIds)}`);
            }
          });
        }
      } catch (error) {
        console.log(`    Collection ${collectionPath} not found or error: ${error.message}`);
      }
    }

    // 5. Check checklist templates
    console.log('\n📋 Checklist Templates:');
    const templatesSnapshot = await db.collection('organizations').doc(orgId).collection('checklist_templates').get();
    
    templatesSnapshot.forEach(doc => {
      const data = doc.data();
      const locationName = locations[data.locationIds?.[0]]?.name || 'Unknown Location';
      console.log(`  ${doc.id}: ${data.name || 'Unnamed'} (${locationName})`);
      console.log(`    Location IDs: ${JSON.stringify(data.locationIds || [])}`);
      console.log(`    Job Types: ${JSON.stringify(data.jobTypes || [])}`);
      
      // Check if this is the problematic template
      if (data.name && data.name.toLowerCase().includes('server') && data.name.toLowerCase().includes('pre dinner')) {
        console.log(`    🚨 POTENTIAL TEMPLATE ISSUE: This appears to be the "C Server - Pre Dinner" template`);
      }
    });

    // 6. Look for specific locationIds mentioned in the screenshots
    console.log('\n🔍 Searching for specific location IDs:');
    
    // From screenshots: Chickies location ID appears to be abTp8sjidL5QVirAewe6
    // Hamilton Pork location ID appears to be fW45ffBBPar5EaNodDYq
    const chickiesId = 'abTp8sjidL5QVirAewe6';
    const hamiltonId = 'fW45ffBBPar5EaNodDYq';
    
    console.log(`Chickies ID (${chickiesId}): ${locations[chickiesId]?.name || 'NOT FOUND'}`);
    console.log(`Hamilton Pork ID (${hamiltonId}): ${locations[hamiltonId]?.name || 'NOT FOUND'}`);

    // 7. Check if there are any cross-references or data corruption
    console.log('\n🔍 Checking for data inconsistencies:');
    
    // Look for any checklists that have Chickies location but are assigned to Hamilton Pork shifts
    const problemChecklists = [];
    
    for (const collectionPath of todayCollections) {
      try {
        const todaySnapshot = await db.collection(collectionPath).get();
        todaySnapshot.forEach(doc => {
          const data = doc.data();
          
          // Check if locationIds contains Chickies but assignedShiftId belongs to Hamilton Pork
          if (data.locationIds && data.locationIds.includes(chickiesId)) {
            const assignedShift = shifts[data.assignedShiftId];
            if (assignedShift && assignedShift.locationIds && assignedShift.locationIds.includes(hamiltonId)) {
              problemChecklists.push({
                id: doc.id,
                name: data.name,
                locationIds: data.locationIds,
                assignedShiftId: data.assignedShiftId,
                shiftName: assignedShift._shiftName || assignedShift.shiftName,
                collection: collectionPath
              });
            }
          }
        });
      } catch (error) {
        // Collection might not exist
      }
    }

    if (problemChecklists.length > 0) {
      console.log('\n🚨 FOUND PROBLEMATIC CHECKLISTS:');
      problemChecklists.forEach(checklist => {
        console.log(`  ${checklist.name} (${checklist.id})`);
        console.log(`    Collection: ${checklist.collection}`);
        console.log(`    Location IDs: ${JSON.stringify(checklist.locationIds)} (Should be Chickies)`);
        console.log(`    Assigned to shift: ${checklist.assignedShiftId} (${checklist.shiftName}) - Hamilton Pork shift`);
        console.log(`    🔧 ISSUE: Checklist has Chickies location but is assigned to Hamilton Pork shift`);
      });
    } else {
      console.log('No obvious cross-location assignment issues found in the data structure.');
    }

  } catch (error) {
    console.error('Error during investigation:', error);
  }
}

// Run the investigation
debugChecklistLocationIssue().then(() => {
  console.log('\n✅ Investigation complete.');
  process.exit(0);
}).catch(error => {
  console.error('Investigation failed:', error);
  process.exit(1);
});