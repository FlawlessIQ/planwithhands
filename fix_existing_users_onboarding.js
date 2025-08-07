// Script to update existing users with onboardingComplete flag
// Run this once to fix existing users who don't have the onboardingComplete flag

const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to set up credentials)
admin.initializeApp();
const db = admin.firestore();

async function fixExistingUsersOnboarding() {
  try {
    console.log('Starting to fix existing users...');
    
    // Get all users who don't have the onboardingComplete field
    const usersSnapshot = await db.collection('users').get();
    
    const batch = db.batch();
    let updatedCount = 0;
    
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      
      // If onboardingComplete field doesn't exist, set it to true for existing users
      if (userData.onboardingComplete === undefined) {
        batch.update(doc.ref, {
          onboardingComplete: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        updatedCount++;
        console.log(`Will update user: ${doc.id} (${userData.email || userData.userEmail})`);
      }
    });
    
    if (updatedCount > 0) {
      await batch.commit();
      console.log(`Successfully updated ${updatedCount} existing users with onboardingComplete: true`);
    } else {
      console.log('No users needed updating');
    }
    
  } catch (error) {
    console.error('Error fixing existing users:', error);
  }
}

// Run the fix
fixExistingUsersOnboarding()
  .then(() => {
    console.log('Fix completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Fix failed:', error);
    process.exit(1);
  });
