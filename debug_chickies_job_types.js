const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function debugUserJobTypeFiltering() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
  const preDinnerShiftId = 'JLo4mc11PpjK9HOdRcdV'; // From the debug output above
  const today = new Date().toISOString().split('T')[0];
  
  console.log('🔍 Debug User Job Type Filtering for Chickies Checklists');
  console.log(`Organization: ${orgId}`);
  console.log(`Location: Chickies (${chickiesLocationId})`);
  console.log(`Shift: Pre Dinner Service (${preDinnerShiftId})`);
  console.log(`Date: ${today}`);
  console.log('==========================================================\n');
  
  try {
    // 1. Get the daily checklists for the Pre Dinner shift
    console.log('📋 DAILY CHECKLISTS for Pre Dinner shift:');
    const checklistsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('locations').doc(chickiesLocationId)
      .collection('daily_checklists')
      .where('shiftId', '==', preDinnerShiftId)
      .where('date', '==', today)
      .get();
    
    console.log(`Found ${checklistsSnapshot.docs.length} checklists for Pre Dinner shift`);
    
    if (checklistsSnapshot.docs.length === 0) {
      console.log('❌ No checklists found for this shift!');
      return;
    }
    
    // 2. Check each checklist's job type requirements
    console.log('\n🎯 CHECKLIST JOB TYPE ANALYSIS:');
    for (const doc of checklistsSnapshot.docs) {
      const data = doc.data();
      const checklistName = data.checklistName || data.templateName || 'Unknown';
      const templateId = data.checklistTemplateId;
      
      console.log(`\n  📋 ${checklistName} (${doc.id})`);
      console.log(`      Template ID: ${templateId}`);
      
      // Get the template to check jobTypes
      if (templateId) {
        try {
          const templateDoc = await db.collection('organizations').doc(orgId)
            .collection('checklist_templates').doc(templateId).get();
          
          if (templateDoc.exists) {
            const templateData = templateDoc.data();
            const jobTypes = templateData.jobTypes || templateData.jobType || [];
            const locationIds = templateData.locationIds || [];
            
            console.log(`      Job Types: ${JSON.stringify(jobTypes)}`);
            console.log(`      Location IDs: ${JSON.stringify(locationIds)}`);
            console.log(`      Includes Chickies: ${locationIds.includes(chickiesLocationId) ? '✅' : '❌'}`);
            
            // Check if this template should be visible
            if (Array.isArray(jobTypes) && jobTypes.length > 0) {
              console.log(`      🔒 JOB TYPE RESTRICTED: Requires one of: ${jobTypes.join(', ')}`);
            } else {
              console.log(`      🌐 UNRESTRICTED: Available to all job types`);
            }
          } else {
            console.log(`      ❌ Template not found!`);
          }
        } catch (error) {
          console.log(`      ❌ Error loading template: ${error.message}`);
        }
      } else {
        console.log(`      ❌ No template ID!`);
      }
    }
    
    // 3. Check what job types would have access
    console.log('\n🔑 JOB TYPE ACCESS ANALYSIS:');
    console.log('For a user to see these checklists, they need:');
    console.log('1. To be assigned to the Pre Dinner Service shift');
    console.log('2. To have the right job type if checklists are job-type restricted');
    console.log('3. To be at the Chickies location');
    
    console.log('\n💡 DEBUGGING TIPS:');
    console.log('1. Check the user\'s job types in the app');
    console.log('2. Check if user is properly assigned to the shift');
    console.log('3. Check if user is at the correct location');
    console.log('4. Look for job type filtering in the Flutter app logs');
    
    // 4. Look for common job types
    console.log('\n🏷️ COMMON JOB TYPES TO CHECK:');
    const commonJobTypes = ['Server', 'Busser', 'Manager', 'Bartender', 'Host', 'Kitchen'];
    commonJobTypes.forEach(jobType => {
      console.log(`   - ${jobType} (case sensitive)`);
    });
    
  } catch (error) {
    console.error('❌ Error debugging job type filtering:', error);
  }
}

debugUserJobTypeFiltering().then(() => {
  console.log('\n✅ Debug complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});