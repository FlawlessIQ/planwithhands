const admin = require('firebase-admin');

// Initialize Firebase with the same method as cleanup script
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Just use default database
const db = admin.firestore();

async function debugShiftsAndTemplates() {
  console.log('🔍 Debugging SHIFTS for organization 3qjYzHagWmfbnMieJ1aj...');
  
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locationIds = ['3mkG9233plgeu94IVE71', 'EazZJYpWQB8XWHw464C2', 'sYhcOTkX1VkeoPjtPuwZ'];
  
  try {
    // Check for shifts in each location
    for (const locationId of locationIds) {
      console.log(`\n📍 Checking shifts in location ${locationId}:`);
      
      const shiftsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('shifts')
        .limit(5)
        .get();
      
      if (shiftsSnapshot.empty) {
        console.log('  No shifts found');
      } else {
        console.log(`  Found ${shiftsSnapshot.docs.length} shifts:`);
        shiftsSnapshot.docs.forEach(doc => {
          const data = doc.data();
          console.log(`  🔄 Shift: ${doc.id}`);
          console.log(`      Name: ${data.name}`);
          console.log(`      Checklists: ${JSON.stringify(data.checklists || [])}`);
          console.log(`      Active: ${data.isActive}`);
          console.log('');
        });
      }
    }
    
    // Also check organization-level shifts
    console.log(`\n� Checking organization-level shifts:`);
    const orgShiftsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .limit(5)
      .get();
    
    if (orgShiftsSnapshot.empty) {
      console.log('  No organization-level shifts found');
    } else {
      console.log(`  Found ${orgShiftsSnapshot.docs.length} organization shifts:`);
      orgShiftsSnapshot.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  🔄 Org Shift: ${doc.id}`);
        console.log(`      Name: ${data.name}`);
        console.log(`      Checklists: ${JSON.stringify(data.checklists || [])}`);
        console.log(`      Active: ${data.isActive}`);
        console.log('');
      });
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  console.log('\n✅ Debug complete');
  process.exit(0);
}

debugShiftsAndTemplates();