const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

async function testSubscriptionGuardLogic() {
  try {
    console.log('🧪 Testing subscription guard logic...\n');
    
    const testOrgId = 'UnfSxn25GWnbrrahhGRa'; // Existing test org
    
    // Test 1: Organization with intendedLocationQuantity set
    console.log('Test 1: Organization with intendedLocationQuantity');
    const orgDoc = await db.collection('organizations').doc(testOrgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      const intendedQuantity = orgData.intendedLocationQuantity;
      console.log(`   Intended quantity: ${intendedQuantity}`);
      
      if (intendedQuantity && intendedQuantity > 0) {
        console.log(`   ✅ Should use intended quantity: ${intendedQuantity}`);
      } else {
        console.log(`   ⚠️ No intended quantity, would fallback to location count`);
      }
    }
    
    // Test 2: Check location count fallback
    console.log('\nTest 2: Location count fallback');
    const locationsQuery = await db.collection('organizations')
      .doc(testOrgId)
      .collection('locations')
      .get();
    
    const locationCount = locationsQuery.size;
    const fallbackQuantity = locationCount > 0 ? locationCount : 1;
    console.log(`   Current locations: ${locationCount}`);
    console.log(`   Fallback quantity: ${fallbackQuantity}`);
    
    // Test 3: Create a test organization without intendedLocationQuantity
    console.log('\nTest 3: Creating test org without intended quantity');
    const testOrgId2 = 'test-legacy-org';
    
    // Create org without intendedLocationQuantity
    await db.collection('organizations').doc(testOrgId2).set({
      name: 'Legacy Test Org',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Add 2 locations
    await db.collection('organizations').doc(testOrgId2).collection('locations').doc('loc1').set({
      name: 'Location 1',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    await db.collection('organizations').doc(testOrgId2).collection('locations').doc('loc2').set({
      name: 'Location 2', 
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Test the logic
    const legacyOrgDoc = await db.collection('organizations').doc(testOrgId2).get();
    const legacyOrgData = legacyOrgDoc.data();
    const legacyIntendedQuantity = legacyOrgData?.intendedLocationQuantity;
    
    if (!legacyIntendedQuantity) {
      const legacyLocationsQuery = await db.collection('organizations')
        .doc(testOrgId2)
        .collection('locations')
        .get();
      
      const legacyLocationCount = legacyLocationsQuery.size;
      const legacyFinalQuantity = legacyLocationCount > 0 ? legacyLocationCount : 1;
      
      console.log(`   Legacy org locations: ${legacyLocationCount}`);
      console.log(`   ✅ Would use location count: ${legacyFinalQuantity}`);
    }
    
    // Cleanup
    await db.collection('organizations').doc(testOrgId2).delete();
    await db.collection('organizations').doc(testOrgId2).collection('locations').doc('loc1').delete();
    await db.collection('organizations').doc(testOrgId2).collection('locations').doc('loc2').delete();
    
    console.log('\n✅ Subscription guard logic test completed');
    
  } catch (error) {
    console.error('❌ Error testing subscription guard logic:', error);
  }
}

testSubscriptionGuardLogic();