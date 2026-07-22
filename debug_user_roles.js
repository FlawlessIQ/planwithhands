const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();

async function debugUserRoles() {
  console.log('👥 === USER ROLES DEBUG ===\n');
  
  try {
    // Check ALL users to see their role data
    console.log('🔍 Analyzing ALL users in the database:');
    const allUsers = await db.collection('users').limit(50).get();
    
    console.log(`Found ${allUsers.size} users total\n`);
    
    const roleCount = { 0: 0, 1: 0, 2: 0, undefined: 0, null: 0, other: 0 };
    const activeCount = { true: 0, false: 0, undefined: 0 };
    
    allUsers.forEach(doc => {
      const data = doc.data();
      const role = data.userRole;
      const isActive = data.isActive;
      const orgId = data.organizationId;
      const name = `${data.firstName || ''} ${data.lastName || ''}`.trim() || 'Unnamed';
      
      // Count roles
      if (role === 0) roleCount[0]++;
      else if (role === 1) roleCount[1]++;
      else if (role === 2) roleCount[2]++;
      else if (role === undefined) roleCount.undefined++;
      else if (role === null) roleCount.null++;
      else roleCount.other++;
      
      // Count active status
      if (isActive === true) activeCount.true++;
      else if (isActive === false) activeCount.false++;
      else activeCount.undefined++;
      
      console.log(`   ${name} (${doc.id})`);
      console.log(`      Org: ${orgId || 'None'}`);
      console.log(`      Role: ${role} (${getRoleName(role)})`);
      console.log(`      Active: ${isActive}`);
      console.log(`      Created: ${data.createdAt?.toDate() || 'Unknown'}\n`);
    });
    
    console.log('📊 Summary Statistics:');
    console.log(`   Role Distribution:`);
    console.log(`      Role 0 (Regular): ${roleCount[0]}`);
    console.log(`      Role 1 (Manager): ${roleCount[1]}`);
    console.log(`      Role 2 (Admin): ${roleCount[2]}`);
    console.log(`      Undefined Role: ${roleCount.undefined}`);
    console.log(`      Null Role: ${roleCount.null}`);
    console.log(`      Other Values: ${roleCount.other}`);
    console.log('');
    console.log(`   Active Status:`);
    console.log(`      Active (true): ${activeCount.true}`);
    console.log(`      Inactive (false): ${activeCount.false}`);
    console.log(`      Undefined: ${activeCount.undefined}`);
    
    // Show admin/manager candidates specifically
    console.log('\n🎯 Admin/Manager Candidates:');
    const adminCandidates = allUsers.docs.filter(doc => {
      const data = doc.data();
      return data.userRole === 1 || data.userRole === 2;
    });
    
    if (adminCandidates.length === 0) {
      console.log('   ❌ NO USERS WITH ROLE 1 OR 2 FOUND!');
      console.log('   This explains why daily summaries are not being sent.');
    } else {
      adminCandidates.forEach(doc => {
        const data = doc.data();
        const name = `${data.firstName || ''} ${data.lastName || ''}`.trim() || 'Unnamed';
        console.log(`   - ${name}: Role ${data.userRole}, Active: ${data.isActive}`);
      });
    }
    
    // Check if we need to create admin users
    console.log('\n💡 Next Steps:');
    if (roleCount[1] === 0 && roleCount[2] === 0) {
      console.log('   1. 🛠️  CREATE ADMIN USERS');
      console.log('      - Update existing users to have userRole = 1 (manager) or 2 (admin)');
      console.log('      - Ensure they have isActive = true');
      console.log('      - Ensure they have valid organizationId');
      console.log('');
      console.log('   2. 🔧 TIMEZONE LOGIC FIX');
      console.log('      - Fix the restrictive timezone logic in scheduledDailySummary.ts');
      console.log('      - This prevents execution for US timezones');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

function getRoleName(role) {
  switch (role) {
    case 0: return 'Regular User';
    case 1: return 'Manager';
    case 2: return 'Admin';
    case undefined: return 'Undefined';
    case null: return 'Null';
    default: return `Unknown (${role})`;
  }
}

debugUserRoles().then(() => {
  console.log('\n✅ User roles debug completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Debug failed:', error);
  process.exit(1);
});