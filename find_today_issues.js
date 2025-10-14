const admin = require('firebase-admin');

// Initialize Firebase Admin with explicit project
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();

async function findTodayChecklists() {
  try {
    const today = '2025-10-12'; // From the screenshot
    
    console.log(`🔍 Searching for checklists on ${today}...\n`);
    
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`Scanning ${orgsSnapshot.docs.length} organizations...\n`);
    
    let foundIssues = 0;
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgId = orgDoc.id;
      const orgName = orgData.name || 'Unnamed';
      
      // Get locations for this org
      const locationsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations')
        .get();
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationData = locationDoc.data();
        const locationName = locationData.name || locationData.locationName || 'Unnamed Location';
        
        // Get today's checklists
        const checklistsSnapshot = await db
          .collection('organizations').doc(orgId)
          .collection('locations').doc(locationId)
          .collection('daily_checklists')
          .where('date', '==', today)
          .get();
        
        if (checklistsSnapshot.docs.length > 0) {
          let orgPrinted = false;
          
          for (const checklistDoc of checklistsSnapshot.docs) {
            const checklistData = checklistDoc.data();
            const checklistId = checklistDoc.id;
            const templateName = checklistData.templateName || 'Unknown Template';
            
            // Get tasks count
            const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
            const totalTasks = tasksSnapshot.docs.length;
            const carryForwardTasks = tasksSnapshot.docs.filter(d => d.data().isCarryForward === true).length;
            const normalTasks = totalTasks - carryForwardTasks;
            
            // Only show if there's an issue
            if ((normalTasks === 0 && totalTasks > 0) || totalTasks === 0) {
              if (!orgPrinted) {
                console.log(`\n${'='.repeat(80)}`);
                console.log(`🏢 Organization: ${orgName}`);
                console.log(`   ID: ${orgId}`);
                console.log(`📍 Location: ${locationName}`);
                console.log(`   ID: ${locationId}`);
                orgPrinted = true;
              }
              
              console.log(`\n   📋 Checklist: ${templateName}`);
              console.log(`      ID: ${checklistId}`);
              console.log(`      Template: ${checklistData.checklistTemplateId || 'None'}`);
              console.log(`      Shift: ${checklistData.shiftId || 'None'}`);
              console.log(`      Total tasks: ${totalTasks}`);
              console.log(`      Normal tasks: ${normalTasks}`);
              console.log(`      Carry-forward tasks: ${carryForwardTasks}`);
              
              if (totalTasks === 0) {
                console.log(`      ⚠️  NO TASKS - Need to seed from template`);
              } else if (normalTasks === 0) {
                console.log(`      ⚠️  ALL TASKS ARE CARRY-FORWARD - THIS IS THE ISSUE!`);
              }
              
              foundIssues++;
            }
          }
        }
      }
    }
    
    console.log(`\n${'='.repeat(80)}`);
    console.log(`\n✅ Scan complete!`);
    console.log(`   Found ${foundIssues} checklists with issues\n`);
    
    if (foundIssues > 0) {
      console.log(`💡 To fix these issues, update the fix script with the correct org/location IDs and run it.`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

findTodayChecklists();
