// Simple script to check help requests in Firestore
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize Firebase Admin
const app = initializeApp();
const db = getFirestore(app);

async function checkHelpRequests() {
  try {
    console.log('🔍 Checking help_requests collection in Firestore...\n');
    
    const snapshot = await db.collection('help_requests')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    if (snapshot.empty) {
      console.log('❌ No help requests found in Firestore');
      return;
    }

    console.log(`✅ Found ${snapshot.size} recent help requests:\n`);
    
    snapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`📧 Help Request #${index + 1}:`);
      console.log(`   ID: ${doc.id}`);
      console.log(`   Email: ${data.email}`);
      console.log(`   Subject: ${data.subject}`);
      console.log(`   Message: ${data.message ? data.message.substring(0, 100) + '...' : 'N/A'}`);
      console.log(`   Timestamp: ${data.timestamp ? data.timestamp.toDate() : 'N/A'}`);
      console.log(`   Status: ${data.status || 'N/A'}`);
      console.log('   ---');
    });

    console.log('\n🎯 Help requests are being stored successfully in:');
    console.log('   Firebase Project: plan-with-hands');
    console.log('   Collection: help_requests');
    console.log('   Console URL: https://console.firebase.google.com/project/plan-with-hands/firestore/data/~2Fhelp_requests');
    
  } catch (error) {
    console.error('❌ Error checking help requests:', error);
  }
  
  process.exit(0);
}

checkHelpRequests();
