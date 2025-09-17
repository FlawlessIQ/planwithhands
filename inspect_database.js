const admin = require('firebase-admin');

// Initialize Firebase Admin with your service account
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const firestore = admin.firestore();

async function inspectDatabase() {
  console.log('🔍 Inspecting database structure...\n');

  try {
    // 1. Check organizations
    console.log('1. Checking organizations collection...');
    const orgsSnapshot = await firestore.collection('organizations').limit(5).get();
    
    if (orgsSnapshot.empty) {
      console.log('   ❌ No organizations found');
    } else {
      console.log(`   ✅ Found ${orgsSnapshot.size} organizations:`);
      orgsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`      - ${doc.id}: ${data.name || 'Unnamed'}`);
      });
    }

    // 2. Check users
    console.log('\n2. Checking users collection...');
    const usersSnapshot = await firestore.collection('users').limit(10).get();
    
    if (usersSnapshot.empty) {
      console.log('   ❌ No users found');
    } else {
      console.log(`   ✅ Found ${usersSnapshot.size} users:`);
      usersSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`      - ${doc.id}: ${data.email || data.displayName || 'Unknown'}`);
        console.log(`        Role: ${data.role || 'None'}`);
        console.log(`        Organization: ${data.organizationId || 'None'}`);
      });
    }

    // 3. Check for any tasks
    console.log('\n3. Checking tasks...');
    const tasksSnapshot = await firestore.collectionGroup('tasks').limit(5).get();
    
    if (tasksSnapshot.empty) {
      console.log('   ❌ No tasks found');
    } else {
      console.log(`   ✅ Found ${tasksSnapshot.size} tasks:`);
      tasksSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`      - ${doc.id}: ${data.title || 'Untitled'}`);
        console.log(`        Organization: ${data.organizationId || 'None'}`);
        console.log(`        Due: ${data.dueDate?.toDate() || 'No date'}`);
      });
    }

    // 4. Check notifications structure
    console.log('\n4. Checking userNotifications...');
    const notificationsSnapshot = await firestore.collection('userNotifications').limit(3).get();
    
    if (notificationsSnapshot.empty) {
      console.log('   ❌ No userNotifications found');
    } else {
      console.log(`   ✅ Found ${notificationsSnapshot.size} userNotifications collections:`);
      for (const doc of notificationsSnapshot.docs) {
        console.log(`      - User: ${doc.id}`);
        const userNotifications = await doc.ref.collection('notifications').limit(3).get();
        console.log(`        Has ${userNotifications.size} notifications`);
      }
    }

    // 5. Check daily summary logs
    console.log('\n5. Checking daily summary logs...');
    const orgs = await firestore.collection('organizations').get();
    
    for (const orgDoc of orgs.docs) {
      const logsSnapshot = await orgDoc.ref.collection('daily_summary_logs').limit(3).get();
      if (!logsSnapshot.empty) {
        console.log(`   📊 Organization ${orgDoc.id} has ${logsSnapshot.size} daily summary logs`);
        logsSnapshot.forEach(logDoc => {
          const logData = logDoc.data();
          console.log(`      - ${logDoc.id}: Sent to ${logData.sentToUserIds?.length || 0} users`);
        });
      }
    }

  } catch (error) {
    console.error('❌ Error inspecting database:', error);
  }
}

// Run the inspection
inspectDatabase().then(() => {
  console.log('\n🏁 Database inspection completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Inspection failed:', error);
  process.exit(1);
});