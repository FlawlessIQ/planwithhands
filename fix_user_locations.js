// Script to fix user location access
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./firebase_config.js'); // Using existing config

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixUserLocationAccess() {
  try {
    console.log('=== FIXING USER LOCATION ACCESS ===');
    
    const selectedLocationId = 'rGAc76DxU9TQhcJy21h0'; // Conors location
    const user1Id = '8CNDD1TxuMYwRNXsiWdllQPnomK2'; // ronoc.ie@gmail.com  
    const user2Id = 'GSMxCCzSnEbqhy1myX5PhBopgIU2'; // conor@flawlessiq.com
    
    console.log('Target location ID:', selectedLocationId);
    console.log('Updating user location access...');
    
    // Update user 1
    await db.collection('users').doc(user1Id).update({
      locationIds: [selectedLocationId],
      primaryLocationId: selectedLocationId
    });
    console.log('✅ Updated user 1 (ronoc.ie@gmail.com)');
    
    // Update user 2  
    await db.collection('users').doc(user2Id).update({
      locationIds: [selectedLocationId],
      primaryLocationId: selectedLocationId
    });
    console.log('✅ Updated user 2 (conor@flawlessiq.com)');
    
    console.log('🎉 Both users now have access to location:', selectedLocationId);
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

fixUserLocationAccess();
