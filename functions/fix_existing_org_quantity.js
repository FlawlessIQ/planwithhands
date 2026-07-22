const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

async function fixExistingOrgQuantity() {
  try {
    console.log('🔧 Fixing existing organization quantity...\n');
    
    const orgId = 'UnfSxn25GWnbrrahhGRa'; // The test organization from debug
    
    console.log(`Updating organization: ${orgId}`);
    
    // Update the organization to set intended location quantity to 3
    // (as reported by the user during account creation)
    await db.collection('organizations').doc(orgId).update({
      intendedLocationQuantity: 3,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ Updated organization with intended location quantity: 3');
    
    // Verify the update
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log(`✅ Verified: intendedLocationQuantity = ${orgData.intendedLocationQuantity}`);
    }
    
  } catch (error) {
    console.error('❌ Error fixing organization quantity:', error);
  }
}

fixExistingOrgQuantity();