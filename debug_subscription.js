const admin = require('firebase-admin');

// Initialize Firebase Admin with service account
const serviceAccount = require('./hands/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function checkSubscriptionStatus() {
  try {
    // Check user data
    const userDoc = await db.collection('users').doc('GSMxCCzSnEbqhy1myX5PhBopgIU2').get();
    if (!userDoc.exists) {
      console.log('User not found');
      return;
    }
    
    const userData = userDoc.data();
    console.log('User data:', {
      userRole: userData.userRole,
      organizationId: userData.organizationId,
      email: userData.email
    });
    
    if (userData.organizationId) {
      // Check organization data
      const orgDoc = await db.collection('organizations').doc(userData.organizationId).get();
      if (orgDoc.exists) {
        const orgData = orgDoc.data();
        console.log('Organization data:', {
          organizationName: orgData.organizationName,
          subscriptionStatus: orgData.subscriptionStatus,
          stripeCustomerId: orgData.stripeCustomerId,
          subscriptionId: orgData.subscriptionId
        });
      } else {
        console.log('Organization not found:', userData.organizationId);
      }
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

checkSubscriptionStatus();
