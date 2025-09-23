const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();

async function fixUserRoles() {
  console.log('🔧 === FIXING USER ROLES ===\n');
  
  try {
    // Get all users
    const allUsers = await db.collection('users').get();
    console.log(`Found ${allUsers.size} users to update\n`);
    
    for (const userDoc of allUsers.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const name = `${userData.firstName || ''} ${userData.lastName || ''}`.trim() || 'Unnamed';
      
      console.log(`Updating user: ${name} (${userId})`);
      
      // Update with admin role and active status
      await userDoc.ref.update({
        userRole: 2, // Admin role
        isActive: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`   ✅ Set to Admin (role 2) and Active\n`);
    }
    
    console.log('🎉 All users updated successfully!');
    console.log('Users now have:');
    console.log('   - userRole: 2 (Admin)');
    console.log('   - isActive: true');
    
  } catch (error) {
    console.error('❌ Error updating users:', error);
  }
}

fixUserRoles().then(() => {
  console.log('\n✅ User role fix completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Fix failed:', error);
  process.exit(1);
});