const admin = require('firebase-admin');

// Initialize Firebase Admin (idempotent)
try {
  admin.initializeApp();
} catch (error) {
  // Already initialized
}

const db = admin.firestore();

async function debugShiftFields() {
  console.log('=== DEBUGGING SHIFT FIELD NAMES ===');
  
  try {
    // List all organizations first
    const allOrgs = await db.collection('organizations').limit(10).get();
    console.log('Available organizations:');
    allOrgs.docs.forEach(doc => {
      const data = doc.data();
      console.log(`- ${doc.id}: ${data.name || 'Unnamed'} (created: ${data.createdAt?.toDate() || 'unknown'})`);
    });
    
    // Now check the specific org
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    console.log(`\n🔍 Checking organization: ${orgId}`);
    
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    
    if (!orgDoc.exists) {
      console.log('❌ Organization not found:', orgId);
      return;
    }
    
    console.log('✅ Organization found:', orgDoc.data().name);
    
    // Check both possible shift locations: org-level and location-level
    console.log('\n� Checking org-level shifts...');
    const shiftsSnap = await db.collection('organizations').doc(orgId).collection('shifts').get();
    console.log(`Found ${shiftsSnap.docs.length} shifts at org level`);
    
    console.log('\n📍 Checking location-level shifts...');
    const locationsSnap = await db.collection('organizations').doc(orgId).collection('locations').get();
    console.log(`Found ${locationsSnap.docs.length} locations`);
    
    if (locationsSnap.docs.length > 0) {
      for (const locDoc of locationsSnap.docs) {
        console.log(`\n  Location: ${locDoc.id} (${locDoc.data().name || 'Unnamed'})`);
        const locShiftsSnap = await db.collection('organizations').doc(orgId)
          .collection('locations').doc(locDoc.id)
          .collection('shifts').get();
        console.log(`  └─ ${locShiftsSnap.docs.length} shifts`);
        
        if (locShiftsSnap.docs.length > 0) {
          locShiftsSnap.docs.forEach(doc => {
            const data = doc.data();
            console.log(`     Shift: ${data.shiftName || doc.id}`);
          });
        }
      }
    }
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

debugShiftFields();