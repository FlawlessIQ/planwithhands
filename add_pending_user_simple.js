// Simple script to add pending user data to Firestore
// Run this with: node add_pending_user_simple.js

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc } = require('firebase/firestore');

// Your Firebase config (you can find this in your Firebase console)
const firebaseConfig = {
  apiKey: "your-api-key",
  authDomain: "plan-with-hands.firebaseapp.com",
  projectId: "plan-with-hands",
  storageBucket: "plan-with-hands.appspot.com",
  messagingSenderId: "your-sender-id",
  appId: "your-app-id"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function addPendingUser() {
  try {
    const pendingUserData = {
      email: 'con.lawless@gmail.com',
      organizationId: 'vnE0olvi1Tswjtdb19MI',
      inviteId: '182536d6-0f16-47c3-8cf6-a6cad8e08635',
      tempPassword: 'temp123',
      firstName: 'Con',
      lastName: 'Lawless',
      userRole: 0,
      createdAt: new Date(),
      status: 'pending'
    };

    const docRef = await addDoc(collection(db, 'pendingUsers'), pendingUserData);
    console.log('✅ Document written with ID: ', docRef.id);
  } catch (error) {
    console.error('❌ Error adding document: ', error);
  }
}

addPendingUser();
