const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

async function quickTest() {
  console.log('Quick daily summary test...');
  
  try {
    const db = admin.firestore();
    
    // Check users quickly
    const users = await db.collection('users').limit(5).get();
    console.log(`Found ${users.size} users`);
    
    users.forEach(doc => {
      const data = doc.data();
      console.log(`User: Role ${data.userRole}, Active: ${data.isActive}`);
    });
    
    console.log('✅ Test completed successfully');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

quickTest();