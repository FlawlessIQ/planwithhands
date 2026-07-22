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

async function deepDiveInvestigation() {
  console.log('🔍 Deep dive investigation...');
  
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  
  try {
    // First, let's get and update the location names
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    const locations = {};
    
    console.log('📍 Location Details:');
    for (const doc of locationsSnapshot.docs) {
      const data = doc.data();
      locations[doc.id] = data;
      console.log(`  ${doc.id}:`);
      console.log(`    Name: ${data.name || 'MISSING NAME'}`);
      console.log(`    Created: ${data.createdAt?.toDate() || 'Unknown'}`);
      console.log(`    Business Type: ${data.businessType || 'Unknown'}`);
      
      // Based on the Firestore screenshots, let's identify the locations:
      if (doc.id === 'abTp8sjidL5QVirAewe6') {
        console.log(`    *** This should be CHICKIES ***`);
      } else if (doc.id === 'fW45ffBBPar5EaNodDYq') {
        console.log(`    *** This should be HAMILTON PORK ***`);
      } else if (doc.id === '9uPGxodhJADOHTCS6Oqz') {
        console.log(`    *** This should be THE HAMILTON INN ***`);
      }
    }

    // Look for the specific shift from your screenshot: oPoQG161AQCaWxMZu9Ch
    const shiftId = 'oPoQG161AQCaWxMZu9Ch'; // (Pork) PRE DINNER SERVICE
    console.log(`\n⏰ Examining shift: ${shiftId}`);
    
    const shiftDoc = await db.collection('organizations').doc(orgId).collection('shifts').doc(shiftId).get();
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      console.log(`  Name: ${shiftData._shiftName || shiftData.shiftName}`);
      console.log(`  Location IDs: ${JSON.stringify(shiftData.locationIds)}`);
      console.log(`  Days: ${JSON.stringify(shiftData.days)}`);
      console.log(`  End Time: ${shiftData.endTime}`);
      console.log(`  Repeats Daily: ${shiftData.repeatsDaily}`);
      console.log(`  Template IDs: ${JSON.stringify(shiftData.checklistTemplateIds)}`);
      
      // Check each template in this shift
      if (shiftData.checklistTemplateIds) {
        console.log('\n  📋 Templates in this shift:');
        for (const templateId of shiftData.checklistTemplateIds) {
          const templateDoc = await db.collection('organizations').doc(orgId).collection('checklist_templates').doc(templateId).get();
          if (templateDoc.exists) {
            const templateData = templateDoc.data();
            console.log(`    ${templateId}: ${templateData.name}`);
            console.log(`      Location IDs: ${JSON.stringify(templateData.locationIds)}`);
            console.log(`      Job Types: ${JSON.stringify(templateData.jobTypes)}`);
            
            // Check if this template belongs to a different location than the shift
            const templateLocationId = templateData.locationIds?.[0];
            const shiftLocationId = shiftData.locationIds?.[0];
            
            if (templateLocationId !== shiftLocationId) {
              console.log(`      🚨 MISMATCH: Template location (${templateLocationId}) != Shift location (${shiftLocationId})`);
            }
          }
        }
      }
    }

    // Now let's look for ANY existing checklist instances that might be causing the issue
    console.log('\n📋 Searching for checklist instances...');
    
    // Search multiple possible date formats and collections
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    
    const datesToCheck = [
      today.toISOString().split('T')[0], // Today: YYYY-MM-DD
      yesterday.toISOString().split('T')[0], // Yesterday: YYYY-MM-DD
      today.toLocaleDateString('en-CA'), // Today in CA format
    ];

    const collectionsToCheck = [
      'today',
      'todayChecklists',
      'dailyChecklists'
    ];

    for (const collection of collectionsToCheck) {
      try {
        // Try direct collection first
        const directPath = `organizations/${orgId}/${collection}`;
        const directSnapshot = await db.collection(directPath).get();
        
        if (!directSnapshot.empty) {
          console.log(`\n  Found ${directSnapshot.size} items in ${directPath}`);
          
          directSnapshot.forEach(doc => {
            const data = doc.data();
            // Look for anything that mentions "Server" and "Pre Dinner"
            if (data.name && data.name.toLowerCase().includes('server') && 
                (data.name.toLowerCase().includes('pre dinner') || data.name.toLowerCase().includes('pre dinner'))) {
              
              console.log(`\n    🎯 Server Pre-Dinner Checklist Found: ${doc.id}`);
              console.log(`      Name: ${data.name}`);
              console.log(`      Template ID: ${data.templateId}`);
              console.log(`      Location IDs: ${JSON.stringify(data.locationIds)}`);
              console.log(`      Assigned Shift: ${data.assignedShiftId}`);
              console.log(`      Job Type: ${data.jobType}`);
              console.log(`      Created: ${data.createdAt?.toDate() || 'Unknown'}`);
              
              // This is likely the problematic checklist!
              if (data.assignedShiftId === shiftId) {
                console.log(`      🚨 THIS IS THE PROBLEM: Assigned to Hamilton Pork shift but should be Chickies!`);
              }
            }
          });
        }
        
        // Try date-based subcollections
        for (const date of datesToCheck) {
          try {
            const dateBasedPath = `organizations/${orgId}/${collection}/${date}/checklists`;
            const dateSnapshot = await db.collection(dateBasedPath).get();
            
            if (!dateSnapshot.empty) {
              console.log(`\n  Found ${dateSnapshot.size} items in ${dateBasedPath}`);
              // Same search logic here if needed
            }
          } catch (e) {
            // Date-based collection might not exist
          }
        }
        
      } catch (error) {
        // Collection might not exist
      }
    }

  } catch (error) {
    console.error('Error during deep investigation:', error);
  }
}

deepDiveInvestigation().then(() => {
  console.log('\n✅ Deep dive investigation complete.');
  process.exit(0);
}).catch(error => {
  console.error('Investigation failed:', error);
  process.exit(1);
});