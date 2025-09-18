const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// Simple version without Stripe API - just check Firestore data

async function debugSubscriptionQuantity() {
  try {
    console.log('🔍 Debugging subscription quantity issue...\n');
    
    // Get recent organizations
    const orgsSnapshot = await db.collection('organizations')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    console.log(`Found ${orgsSnapshot.size} recent organizations:\n`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgId = orgDoc.id;
      
      console.log(`📋 Organization: ${orgData.name || 'Unnamed'} (${orgId})`);
      console.log(`   Created: ${orgData.createdAt?.toDate?.() || 'Unknown'}`);
      
      // Check subscription data in subcollection
      const subSnapshot = await db.collection('organizations')
        .doc(orgId)
        .collection('stripe')
        .doc('subscription')
        .get();
      
      if (subSnapshot.exists) {
        const subData = subSnapshot.data();
      console.log(`   📦 Firestore subscription data:`);
      console.log(`      Status: ${subData.status}`);
      console.log(`      Subscription ID: ${subData.subscriptionId}`);
      console.log(`      Quantity: ${subData.quantity || 'Not set'}`);
      
      // Get organization data to check for intended quantity
      const orgDoc = await db.collection('organizations').doc(orgId).get();
      if (orgDoc.exists) {
        const orgData = orgDoc.data();
        console.log(`   🏢 Organization data:`);
        console.log(`      Intended location quantity: ${orgData.intendedLocationQuantity || 'Not set'}`);
        console.log(`      Created: ${orgData.createdAt?.toDate?.() || 'Unknown'}`);
      }        // Get actual locations count
        const locationsSnapshot = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .get();
        
        console.log(`   📍 Actual locations count: ${locationsSnapshot.size}`);
        
        // Check Stripe subscription - skip for now
        if (subData.subscriptionId) {
          console.log(`   💳 Stripe subscription ID: ${subData.subscriptionId}`);
          console.log(`      (Skipping Stripe API call - focusing on Firestore data)`);
        }
      } else {
        console.log(`   ❌ No subscription data found in Firestore`);
      }
      
      console.log(''); // Empty line for readability
    }
    
  } catch (error) {
    console.error('❌ Error during debugging:', error);
  }
}

debugSubscriptionQuantity();