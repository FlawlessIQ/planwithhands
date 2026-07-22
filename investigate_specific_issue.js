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

async function investigateSpecificIssue() {
  console.log('🔍 Investigating specific checklist assignment issue...');
  
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  
  try {
    // First, let's get the location names
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    const locations = {};
    
    locationsSnapshot.forEach(doc => {
      const data = doc.data();
      locations[doc.id] = data.name || 'Unnamed';
    });
    
    console.log('📍 Locations:');
    Object.entries(locations).forEach(([id, name]) => {
      console.log(`  ${id}: ${name}`);
    });

    // Get the problematic template
    const problemTemplateId = 'GRK7wpSsAHS2z66WFGMz'; // C Server - Pre DInner
    const templateDoc = await db.collection('organizations').doc(orgId).collection('checklist_templates').doc(problemTemplateId).get();
    
    if (templateDoc.exists) {
      const templateData = templateDoc.data();
      console.log('\n🎯 Problematic Template:');
      console.log(`  ID: ${problemTemplateId}`);
      console.log(`  Name: ${templateData.name}`);
      console.log(`  Location IDs: ${JSON.stringify(templateData.locationIds)}`);
      console.log(`  Expected Location: ${locations[templateData.locationIds?.[0]] || 'Unknown'}`);
    }

    // Get the Pork PRE DINNER SERVICE shift
    const problemShiftId = 'oPoQG161AQCaWxMZu9Ch';
    const shiftDoc = await db.collection('organizations').doc(orgId).collection('shifts').doc(problemShiftId).get();
    
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      console.log('\n⏰ Problematic Shift:');
      console.log(`  ID: ${problemShiftId}`);
      console.log(`  Name: ${shiftData._shiftName || shiftData.shiftName}`);
      console.log(`  Location IDs: ${JSON.stringify(shiftData.locationIds)}`);
      console.log(`  Actual Location: ${locations[shiftData.locationIds?.[0]] || 'Unknown'}`);
      console.log(`  Template IDs: ${JSON.stringify(shiftData.checklistTemplateIds)}`);
      
      // Check if the problematic template is in this shift's templates
      const hasProblematicTemplate = shiftData.checklistTemplateIds?.includes(problemTemplateId);
      console.log(`  Contains C Server Pre-Dinner template: ${hasProblematicTemplate}`);
      
      if (hasProblematicTemplate) {
        console.log('\n🚨 ISSUE IDENTIFIED:');
        console.log('  The Pork PRE DINNER SERVICE shift includes the Chickies "C Server - Pre DInner" template!');
        console.log('  This is causing Chickies checklists to appear under Hamilton Pork shifts.');
      }
    }

    // Look for today's actual checklist instances
    console.log('\n📋 Looking for today\'s checklist instances...');
    
    const today = new Date();
    const todayString = today.toISOString().split('T')[0]; // YYYY-MM-DD
    
    // Check multiple possible collections for today's checklists
    const possibleCollections = [
      `organizations/${orgId}/today`,
      `organizations/${orgId}/todayChecklists`,
      `organizations/${orgId}/dailyChecklists/${todayString}/checklists`
    ];

    for (const collectionPath of possibleCollections) {
      try {
        const snapshot = await db.collection(collectionPath).get();
        if (!snapshot.empty) {
          console.log(`\n  Found checklists in: ${collectionPath} (${snapshot.size} items)`);
          
          snapshot.forEach(doc => {
            const data = doc.data();
            
            // Look for checklists that match our problem case
            if (data.templateId === problemTemplateId || 
                (data.name && data.name.toLowerCase().includes('server') && data.name.toLowerCase().includes('pre dinner'))) {
              
              console.log(`\n    🎯 Found problematic checklist: ${doc.id}`);
              console.log(`      Name: ${data.name}`);
              console.log(`      Template ID: ${data.templateId}`);
              console.log(`      Location IDs: ${JSON.stringify(data.locationIds)}`);
              console.log(`      Assigned Shift: ${data.assignedShiftId}`);
              console.log(`      Job Type: ${data.jobType}`);
              
              // Determine what location this checklist thinks it belongs to
              const checklistLocation = locations[data.locationIds?.[0]];
              const assignedShiftLocation = shiftDoc.exists ? locations[shiftDoc.data().locationIds?.[0]] : 'Unknown';
              
              console.log(`      Checklist thinks it's at: ${checklistLocation}`);
              console.log(`      But assigned to shift at: ${assignedShiftLocation}`);
              
              if (checklistLocation !== assignedShiftLocation) {
                console.log(`      🚨 MISMATCH CONFIRMED!`);
              }
            }
          });
        }
      } catch (error) {
        // Collection might not exist
      }
    }

    // Provide fix recommendations
    console.log('\n💡 RECOMMENDED FIXES:');
    console.log('1. Remove template GRK7wpSsAHS2z66WFGMz (C Server - Pre DInner) from shift oPoQG161AQCaWxMZu9Ch (Pork PRE DINNER SERVICE)');
    console.log('2. Verify that all shift templates belong to the same location as the shift');
    console.log('3. Check if there should be a separate "P Server - Pre Dinner" template for Hamilton Pork location');

  } catch (error) {
    console.error('Error during investigation:', error);
  }
}

investigateSpecificIssue().then(() => {
  console.log('\n✅ Specific investigation complete.');
  process.exit(0);
}).catch(error => {
  console.error('Investigation failed:', error);
  process.exit(1);
});