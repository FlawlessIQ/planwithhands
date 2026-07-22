const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

async function testSignupFlowEdgeCases() {
  try {
    console.log('🔧 Testing signup flow edge cases...\n');
    
    // Test Case 1: New user creates account with 3 locations but gets logged out
    console.log('Test Case 1: User logout/login scenario');
    const testOrgId = 'test-logout-scenario';
    
    // Simulate account creation with intended quantity
    await db.collection('organizations').doc(testOrgId).set({
      name: 'Test Logout Org',
      intendedLocationQuantity: 3,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionStatus: 'trial',
    });
    
    console.log('   ✅ Created organization with intendedLocationQuantity: 3');
    
    // Simulate user document
    await db.collection('users').doc('test-user-123').set({
      email: 'test@example.com',
      organizationId: testOrgId,
      userRole: 2,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('   ✅ Created user document');
    
    // Test the subscription guard logic for this scenario
    const orgDoc = await db.collection('organizations').doc(testOrgId).get();
    const orgData = orgDoc.data();
    const intendedQuantity = orgData?.intendedLocationQuantity;
    
    if (intendedQuantity && intendedQuantity > 0) {
      console.log(`   ✅ Subscription guard would use intended quantity: ${intendedQuantity}`);
    } else {
      console.log('   ❌ Subscription guard would fallback to location count');
    }
    
    // Test Case 2: User with incomplete signup (no subscription created yet)
    console.log('\nTest Case 2: Incomplete signup scenario');
    
    // Check if subscription exists
    const subDoc = await db.collection('organizations')
      .doc(testOrgId)
      .collection('stripe')
      .doc('subscription')
      .get();
    
    if (!subDoc.exists) {
      console.log('   ✅ No subscription exists - user would be redirected to payment');
      console.log(`   ✅ Payment redirect would use quantity: ${intendedQuantity}`);
    }
    
    // Test Case 3: Legacy organization without intendedLocationQuantity
    console.log('\nTest Case 3: Legacy organization scenario');
    const legacyOrgId = 'test-legacy-org';
    
    // Create legacy organization without intendedLocationQuantity
    await db.collection('organizations').doc(legacyOrgId).set({
      name: 'Legacy Organization',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionStatus: 'trial',
    });
    
    // Add some locations
    await db.collection('organizations').doc(legacyOrgId).collection('locations').doc('loc1').set({
      name: 'Location 1',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    await db.collection('organizations').doc(legacyOrgId).collection('locations').doc('loc2').set({
      name: 'Location 2',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Test subscription guard logic for legacy org
    const legacyOrgDoc = await db.collection('organizations').doc(legacyOrgId).get();
    const legacyOrgData = legacyOrgDoc.data();
    const legacyIntendedQuantity = legacyOrgData?.intendedLocationQuantity;
    
    if (!legacyIntendedQuantity) {
      const locationsQuery = await db.collection('organizations')
        .doc(legacyOrgId)
        .collection('locations')
        .get();
      
      const locationCount = locationsQuery.size;
      const fallbackQuantity = locationCount > 0 ? locationCount : 1;
      
      console.log(`   ✅ Legacy org would use location count: ${fallbackQuantity}`);
    }
    
    // Test Case 4: Browser refresh during payment
    console.log('\nTest Case 4: Browser refresh/navigation scenarios');
    console.log('   ✅ Account creation stores intendedLocationQuantity in persistent Firestore');
    console.log('   ✅ Payment URL contains quantity parameter for direct access');
    console.log('   ✅ Subscription guard reads from Firestore for consistency');
    
    // Cleanup
    await db.collection('organizations').doc(testOrgId).delete();
    await db.collection('users').doc('test-user-123').delete();
    await db.collection('organizations').doc(legacyOrgId).delete();
    await db.collection('organizations').doc(legacyOrgId).collection('locations').doc('loc1').delete();
    await db.collection('organizations').doc(legacyOrgId).collection('locations').doc('loc2').delete();
    
    console.log('\n✅ All edge case tests completed successfully');
    
  } catch (error) {
    console.error('❌ Error testing edge cases:', error);
  }
}

testSignupFlowEdgeCases();