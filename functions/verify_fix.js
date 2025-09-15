const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');

admin.initializeApp();

async function verifyFix() {
  try {
    const userId = 'ah9OSUi87LhFTkewui8gZVM3ijC2';
    const db = getFirestore();
    
    console.log('🔍 Verifying user location assignment...');
    
    const userDoc = await db.collection('users').doc(userId).get();
    if (userDoc.exists) {
      const data = userDoc.data();
      console.log('✅ User document found:');
      console.log('   locationIds:', data.locationIds);
      console.log('   locationId:', data.locationId);
      console.log('   organizationId:', data.organizationId);
    } else {
      console.log('❌ User document not found');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyFix();
