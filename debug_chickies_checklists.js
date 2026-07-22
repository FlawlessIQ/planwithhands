const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function debugChickiesChecklists() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M'; // Your organization ID
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD format
  
  console.log('🔍 Debug Chickies Checklists Issue');
  console.log(`Organization: ${orgId}`);
  console.log(`Date: ${today}`);
  console.log('=====================================\n');
  
  try {
    // 1. Check all locations for this organization
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    
    console.log('📍 LOCATIONS:');
    const chickiesLocations = [];
    locationsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const locationName = data.name || data.locationName || 'Unknown';
      console.log(`  ${doc.id}: ${locationName}`);
      
      if (locationName.toLowerCase().includes('chickies')) {
        chickiesLocations.push({id: doc.id, name: locationName});
      }
    });
    
    if (chickiesLocations.length === 0) {
      console.log('❌ No Chickies locations found!');
      return;
    }
    
    console.log(`\n🎯 Found ${chickiesLocations.length} Chickies location(s):`);
    chickiesLocations.forEach(loc => console.log(`  - ${loc.id}: ${loc.name}`));
    
    // 2. Check shifts for Chickies locations
    console.log('\n🔄 SHIFTS:');
    for (const chickiesLoc of chickiesLocations) {
      const shiftsSnapshot = await db.collection('organizations').doc(orgId).collection('shifts')
        .where('locationIds', 'array-contains', chickiesLoc.id)
        .get();
      
      console.log(`\n  📍 ${chickiesLoc.name} (${chickiesLoc.id}): ${shiftsSnapshot.docs.length} shifts`);
      
      const shiftIds = [];
      shiftsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const shiftName = data.shiftName || 'Unknown Shift';
        const checklistTemplateIds = data.checklistTemplateIds || [];
        console.log(`    - ${doc.id}: ${shiftName} (${checklistTemplateIds.length} templates)`);
        shiftIds.push(doc.id);
      });
      
      // 3. Check daily checklists for today for each shift
      console.log(`\n  📅 TODAY'S DAILY CHECKLISTS for ${chickiesLoc.name}:`);
      const dailyChecklistsSnapshot = await db.collection('organizations').doc(orgId)
        .collection('locations').doc(chickiesLoc.id)
        .collection('daily_checklists')
        .where('date', '==', today)
        .get();
      
      console.log(`    Found ${dailyChecklistsSnapshot.docs.length} daily checklists for today`);
      
      if (dailyChecklistsSnapshot.docs.length === 0) {
        console.log('    ❌ NO DAILY CHECKLISTS FOUND FOR TODAY!');
        console.log('    This explains why checklists don\'t show up in the app.');
        
        // Check if shifts are scheduled for today
        const todayDayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][new Date().getDay() - 1];
        console.log(`    Today is: ${todayDayName}`);
        
        shiftsSnapshot.docs.forEach(doc => {
          const data = doc.data();
          const shiftName = data.shiftName || 'Unknown Shift';
          const repeatsDaily = data.repeatsDaily || false;
          const days = data.days || [];
          
          const isScheduledToday = repeatsDaily || days.includes(todayDayName);
          console.log(`    - ${shiftName}: Scheduled today? ${isScheduledToday ? '✅' : '❌'} (repeatsDaily: ${repeatsDaily}, days: ${days.join(', ')})`);
        });
        
      } else {
        dailyChecklistsSnapshot.docs.forEach(doc => {
          const data = doc.data();
          const checklistName = data.checklistName || data.templateName || 'Unknown Checklist';
          const shiftId = data.shiftId || 'Unknown Shift';
          const templateId = data.checklistTemplateId || 'Unknown Template';
          console.log(`    - ${doc.id}: ${checklistName} (shift: ${shiftId}, template: ${templateId})`);
        });
      }
    }
    
    // 4. Check if daily checklist generation should have run
    console.log('\n⚙️ DAILY CHECKLIST GENERATION CHECK:');
    console.log('Daily checklists should be generated automatically by Cloud Functions.');
    console.log('If no checklists exist for today, the generation might have failed or not run.');
    
    console.log('\n💡 SOLUTIONS:');
    console.log('1. Check Cloud Function logs for daily checklist generation');
    console.log('2. Manually trigger daily checklist generation');
    console.log('3. Verify shift scheduling and template assignments');
    
  } catch (error) {
    console.error('❌ Error debugging Chickies checklists:', error);
  }
}

debugChickiesChecklists().then(() => {
  console.log('\n✅ Debug complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});