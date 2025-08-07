const { db } = require('./functions/firebase_config.js');

async function createPendingUser() {
  try {
    const pendingUserData = {
      email: 'con.lawless@gmail.com',
      organizationId: 'vnE0olvi1Tswjtdb19MI',
      inviteId: '182536d6-0f16-47c3-8cf6-a6cad8e08635',
      tempPassword: 'temp123', // Temporary password for the user
      firstName: 'Con',
      lastName: 'Lawless',
      userRole: 0, // Regular user role
      createdAt: new Date(),
      status: 'pending'
    };

    // Add document to pendingUsers collection
    const docRef = await db.collection('pendingUsers').add(pendingUserData);
    console.log('✅ Pending user document created with ID:', docRef.id);
    console.log('📧 Email:', pendingUserData.email);
    console.log('🏢 Organization ID:', pendingUserData.organizationId);
    console.log('🔗 Invite ID:', pendingUserData.inviteId);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating pending user:', error);
    process.exit(1);
  }
}

console.log('🚀 Creating pending user document...');
createPendingUser();
