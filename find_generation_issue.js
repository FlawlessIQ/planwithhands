const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');
const orgId = '3qjYzHagWmfbnMieJ1aj';

async function findAndFixGenerationIssue() {
  console.log('🔍 FINDING GENERATION ISSUE ROOT CAUSE');
  console.log(`Organization: ${orgId}`);
  console.log('=' .repeat(80));
  
  try {
    // 1. Check if there are any shifts with invalid template references
    console.log('1️⃣ CHECKING ALL SHIFTS IN DATABASE:');
    
    // Check organization-specific shifts
    const orgShiftsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('shifts').get();
    console.log(`Organization shifts: ${orgShiftsSnapshot.size}`);
    
    // Check global shifts that might reference this organization
    const globalShiftsSnapshot = await db.collection('shifts').get();
    console.log(`Global shifts: ${globalShiftsSnapshot.size}`);
    
    // Analyze any shifts that reference this organization or location
    const allShifts = [...orgShiftsSnapshot.docs, ...globalShiftsSnapshot.docs];
    const relevantShifts = [];
    
    for (const shiftDoc of allShifts) {
      const shiftData = shiftDoc.data();
      const locationIds = shiftData.locationIds || shiftData.locationId || [];
      const orgLocationIds = ['sYhcOTkX1VkeoPjtPuwZ', 'EaZZJYpWQ6XHm464C2', '3mkG923plqeu94IVE71']; // from your screenshot
      
      // Check if this shift applies to any locations in our problem org
      const appliesToOrg = Array.isArray(locationIds) 
        ? locationIds.some(id => orgLocationIds.includes(id))
        : orgLocationIds.includes(locationIds);
      
      if (appliesToOrg) {
        relevantShifts.push({
          id: shiftDoc.id,
          data: shiftData,
          collection: shiftDoc.ref.parent.path
        });
      }
    }
    
    console.log(`Found ${relevantShifts.length} shifts that apply to this organization:`);
    relevantShifts.forEach(shift => {
      console.log(`  - ${shift.id} (${shift.collection}):`);
      console.log(`    Name: ${shift.data.name || 'No name'}`);
      console.log(`    Location IDs: ${JSON.stringify(shift.data.locationIds || shift.data.locationId || [])}`);
      console.log(`    Template IDs: ${JSON.stringify(shift.data.checklistTemplateIds || [])}`);
    });
    
    // 2. Look for any automation or scheduled functions that might be creating these
    console.log('\n2️⃣ CHECKING FOR RECENT CHECKLISTS PATTERNS:');
    
    const locationIds = ['sYhcOTkX1VkeoPjtPuwZ', 'EaZZJYpWQ6XHm464C2', '3mkG923plqeu94IVE71'];
    
    for (const locationId of locationIds) {
      console.log(`\n📍 Location: ${locationId}`);
      
      const recentChecklists = await db.collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get();
      
      console.log(`  Recent checklists: ${recentChecklists.size}`);
      
      recentChecklists.docs.forEach(doc => {
        const data = doc.data();
        console.log(`    - ${doc.id}:`);
        console.log(`      Date: ${data.date}`);
        console.log(`      Created by: ${data.createdBy}`);
        console.log(`      Shift ID: ${data.shiftId}`);
        console.log(`      Template IDs: ${JSON.stringify(data.checklistTemplateIds || [])}`);
        
        // Check if this has the problem pattern
        if (doc.id.includes('aEwRngcnvjSh1glH19oz')) {
          console.log(`      ⚠️  PROBLEM PATTERN DETECTED`);
        }
      });
    }
    
    // 3. Check if daily generator is enabled for this org
    console.log('\n3️⃣ ORGANIZATION CONFIGURATION:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log('Organization settings:');
      console.log(`  Name: ${orgData.name || 'Not set'}`);
      console.log(`  Timezone: ${orgData.timezone || 'Not set'}`);
      console.log(`  Daily Summary: ${JSON.stringify(orgData.dailySummarySettings || 'Not set')}`);
      console.log(`  Settings: ${JSON.stringify(orgData.settings || 'Not set')}`);
    }
    
    // 4. SOLUTION: Disable or fix the problematic configuration
    console.log('\n4️⃣ RECOMMENDED ACTIONS:');
    
    if (relevantShifts.length === 0) {
      console.log('✅ No problematic shifts found');
      console.log('💡 The issue might be:');
      console.log('   1. Daily generator creating checklists without proper shift validation');
      console.log('   2. Stale data or manual checklist creation');
      console.log('   3. App-level checklist generation bypassing validation');
      
      console.log('\n🛠️  IMMEDIATE SOLUTION:');
      console.log('Since no shifts are configured for this organization,');
      console.log('the daily generator should NOT be creating any checklists.');
      console.log('This suggests a bug in the generator\'s validation logic.');
      
    } else {
      console.log('❌ Found problematic shift configurations');
      console.log('🛠️  You need to:');
      console.log('   1. Fix or delete invalid shifts');
      console.log('   2. Update template references in shifts');
      console.log('   3. Ensure proper validation in daily generator');
    }
    
    // 5. Check if we can disable generation for this org temporarily
    console.log('\n5️⃣ TEMPORARY DISABLE OPTION:');
    console.log('To immediately stop checklist generation, you could:');
    console.log('1. Remove timezone from organization (generator skips orgs without timezone)');
    console.log('2. Remove all locations from organization');
    console.log('3. Add a "disabled" flag to organization settings');
    
  } catch (error) {
    console.error('❌ Error finding generation issue:', error);
  }
  
  process.exit(0);
}

findAndFixGenerationIssue();