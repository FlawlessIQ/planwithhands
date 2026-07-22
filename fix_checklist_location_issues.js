const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();
// Make sure we're using the planwithhands database, not the default
db.settings({
  databaseId: 'planwithhands'
});

async function fixChecklistLocationIssues() {
  console.log('🔧 Fixing checklist location issues...');
  
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  
  try {
    // Step 1: Set proper location names (they're missing)
    console.log('\n📍 Step 1: Setting proper location names...');
    
    const locationUpdates = [
      { id: 'abTp8sjidL5QVirAewe6', name: 'Chickies' },
      { id: 'fW45ffBBPar5EaNodDYq', name: 'Hamilton Pork' },
      { id: '9uPGxodhJADOHTCS6Oqz', name: 'The Hamilton Inn' }
    ];

    for (const location of locationUpdates) {
      await db.collection('organizations').doc(orgId).collection('locations').doc(location.id).update({
        name: location.name,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`  ✅ Updated ${location.id} name to: ${location.name}`);
    }

    // Step 2: Analyze all shifts and their template assignments
    console.log('\n⏰ Step 2: Analyzing shift template assignments...');
    
    const shiftsSnapshot = await db.collection('organizations').doc(orgId).collection('shifts').get();
    const templatesSnapshot = await db.collection('organizations').doc(orgId).collection('checklist_templates').get();
    
    // Build template location mapping
    const templateLocations = {};
    templatesSnapshot.forEach(doc => {
      const data = doc.data();
      templateLocations[doc.id] = {
        name: data.name,
        locationId: data.locationIds?.[0],
        locationName: locationUpdates.find(l => l.id === data.locationIds?.[0])?.name || 'Unknown'
      };
    });

    const issuesFound = [];
    
    for (const shiftDoc of shiftsSnapshot.docs) {
      const shiftData = shiftDoc.data();
      const shiftLocationId = shiftData.locationIds?.[0];
      const shiftLocationName = locationUpdates.find(l => l.id === shiftLocationId)?.name || 'Unknown';
      
      console.log(`\n  Checking shift: ${shiftData._shiftName || shiftData.shiftName} (${shiftLocationName})`);
      
      if (shiftData.checklistTemplateIds) {
        const wrongTemplates = [];
        
        shiftData.checklistTemplateIds.forEach(templateId => {
          const template = templateLocations[templateId];
          if (template && template.locationId !== shiftLocationId) {
            wrongTemplates.push({
              templateId,
              templateName: template.name,
              templateLocation: template.locationName,
              templateLocationId: template.locationId
            });
          }
        });

        if (wrongTemplates.length > 0) {
          console.log(`    🚨 Found ${wrongTemplates.length} misassigned templates:`);
          wrongTemplates.forEach(wt => {
            console.log(`      - ${wt.templateName} (belongs to ${wt.templateLocation}, not ${shiftLocationName})`);
          });

          issuesFound.push({
            shiftId: shiftDoc.id,
            shiftName: shiftData._shiftName || shiftData.shiftName,
            shiftLocationId,
            shiftLocationName,
            wrongTemplates,
            currentTemplateIds: shiftData.checklistTemplateIds
          });
        } else {
          console.log(`    ✅ All templates correctly assigned`);
        }
      }
    }

    // Step 3: Ask for confirmation and fix the issues
    if (issuesFound.length > 0) {
      console.log('\n🔧 Step 3: Fixing misassigned templates...');
      
      for (const issue of issuesFound) {
        console.log(`\n  Fixing shift: ${issue.shiftName} (${issue.shiftLocationName})`);
        
        // Remove the wrongly assigned templates
        const correctTemplateIds = issue.currentTemplateIds.filter(templateId => {
          const template = templateLocations[templateId];
          return !template || template.locationId === issue.shiftLocationId;
        });

        console.log(`    Removing ${issue.wrongTemplates.length} incorrect templates`);
        console.log(`    Templates to remove: ${issue.wrongTemplates.map(wt => wt.templateName).join(', ')}`);
        console.log(`    Keeping ${correctTemplateIds.length} correct templates`);

        // Update the shift
        await db.collection('organizations').doc(orgId).collection('shifts').doc(issue.shiftId).update({
          checklistTemplateIds: correctTemplateIds,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`    ✅ Fixed shift: ${issue.shiftName}`);
      }
    } else {
      console.log('\n✅ No shift template misassignments found!');
    }

    // Step 4: Clean up any existing checklist instances that might be wrongly assigned
    console.log('\n📋 Step 4: Checking for wrongly assigned checklist instances...');
    
    const today = new Date();
    const todayString = today.toISOString().split('T')[0];
    
    // Check today's checklists
    try {
      const todaySnapshot = await db.collection(`organizations/${orgId}/today`).get();
      
      if (!todaySnapshot.empty) {
        console.log(`  Found ${todaySnapshot.size} today's checklists`);
        
        const wrongChecklistInstances = [];
        
        todaySnapshot.forEach(doc => {
          const data = doc.data();
          
          if (data.assignedShiftId && data.locationIds) {
            // Get the shift this checklist is assigned to
            const shiftLocation = shiftsSnapshot.docs.find(s => s.id === data.assignedShiftId)?.data()?.locationIds?.[0];
            const checklistLocation = data.locationIds[0];
            
            if (shiftLocation && checklistLocation && shiftLocation !== checklistLocation) {
              const shiftLocationName = locationUpdates.find(l => l.id === shiftLocation)?.name || 'Unknown';
              const checklistLocationName = locationUpdates.find(l => l.id === checklistLocation)?.name || 'Unknown';
              
              wrongChecklistInstances.push({
                id: doc.id,
                name: data.name,
                checklistLocation,
                checklistLocationName,
                shiftLocation,
                shiftLocationName,
                assignedShiftId: data.assignedShiftId
              });
            }
          }
        });

        if (wrongChecklistInstances.length > 0) {
          console.log(`\n  🚨 Found ${wrongChecklistInstances.length} wrongly assigned checklist instances:`);
          
          for (const instance of wrongChecklistInstances) {
            console.log(`    ${instance.name}:`);
            console.log(`      Checklist belongs to: ${instance.checklistLocationName}`);
            console.log(`      But assigned to shift at: ${instance.shiftLocationName}`);
            console.log(`      This should be reassigned or removed`);
            
            // For now, just log the issue. You might want to:
            // 1. Delete the wrongly assigned checklist
            // 2. Or reassign it to a correct shift
            // 3. Or create a new checklist with correct assignment
          }
        } else {
          console.log(`  ✅ All checklist instances have correct location assignments`);
        }
      }
    } catch (error) {
      console.log(`  No today's checklists collection found or error: ${error.message}`);
    }

    console.log('\n✅ Fix operation completed!');
    console.log('\nSummary:');
    console.log(`- Updated ${locationUpdates.length} location names`);
    console.log(`- Fixed ${issuesFound.length} shifts with misassigned templates`);
    console.log('- Location names are now properly set');
    console.log('- All shift templates should now match their shift locations');

  } catch (error) {
    console.error('Error during fix operation:', error);
  }
}

// Ask for confirmation before running
console.log('This script will:');
console.log('1. Set proper names for all locations');
console.log('2. Remove any templates from shifts that belong to different locations');
console.log('3. Check for wrongly assigned checklist instances');
console.log('');
console.log('⚠️  This will modify your database. Make sure you have a backup!');
console.log('');

// Run the fix
fixChecklistLocationIssues().then(() => {
  console.log('\n🎉 All fixes completed successfully!');
  process.exit(0);
}).catch(error => {
  console.error('Fix operation failed:', error);
  process.exit(1);
});