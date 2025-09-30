const admin = require('firebase-admin');

// Initialize Firebase Admin with the planwithhands database
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com/'
  });
}

// Use the planwithhands database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function debugOrgDailySummary(orgId) {
  console.log(`🔍 Debug Daily Summary for Organization: ${orgId}`);
  console.log(`📅 Date: ${new Date().toISOString()}`);
  
  try {
    // 1. Check organization exists
    console.log('\n1️⃣ Checking organization...');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    const orgData = orgDoc.data();
    console.log(`✅ Organization found: ${orgData.name || orgData.organizationName || 'Unknown'}`);
    
    // 2. Check daily summary settings
    console.log('\n2️⃣ Checking daily summary settings...');
    const settingsDoc = await db.collection('organizations').doc(orgId).collection('settings').doc('dailySummarySettings').get();
    if (settingsDoc.exists) {
      const settings = settingsDoc.data();
      console.log('✅ Daily summary settings found:');
      console.log(`   Hour: ${settings.hour}`);
      console.log(`   Minute: ${settings.minute}`);
      console.log(`   Enabled: ${settings.enabled}`);
      console.log(`   Last Updated: ${settings.lastUpdated?.toDate()}`);
    } else {
      console.log('❌ No daily summary settings found');
    }
    
    // 3. Check for admin users
    console.log('\n3️⃣ Checking admin users...');
    const adminQuery = await db.collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', 'in', [1, 2])
      .where('isActive', '==', true)
      .get();
    
    console.log(`✅ Found ${adminQuery.docs.length} admin users:`);
    adminQuery.docs.forEach(doc => {
      const user = doc.data();
      console.log(`   - ${user.firstName} ${user.lastName} (${user.email}) - Role: ${user.userRole}`);
    });
    
    // 4. Check locations
    console.log('\n4️⃣ Checking locations...');
    const locationsQuery = await db.collection('organizations').doc(orgId).collection('locations').get();
    console.log(`✅ Found ${locationsQuery.docs.length} locations:`);
    locationsQuery.docs.forEach(doc => {
      const location = doc.data();
      console.log(`   - ${location.locationName} (${doc.id})`);
    });
    
    // 5. Check for today's data
    console.log('\n5️⃣ Checking today\'s checklist data...');
    const today = new Date();
    const dateStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    console.log(`   Looking for date: ${dateStr}`);
    
    let totalChecklists = 0;
    let totalTasks = 0;
    for (const locationDoc of locationsQuery.docs) {
      const checklistsQuery = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationDoc.id)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .get();
      
      console.log(`   - ${locationDoc.data().locationName}: ${checklistsQuery.docs.length} checklists`);
      totalChecklists += checklistsQuery.docs.length;
      
      for (const checklistDoc of checklistsQuery.docs) {
        const checklistData = checklistDoc.data();
        const tasks = checklistData.tasks || [];
        totalTasks += tasks.length;
        
        // Also check subcollection tasks
        const subTasks = await checklistDoc.ref.collection('tasks').get();
        totalTasks += subTasks.docs.length;
      }
    }
    
    console.log(`📊 Total checklists for today: ${totalChecklists}`);
    console.log(`📊 Total tasks for today: ${totalTasks}`);
    
    // 6. Check if daily summary was already sent today
    console.log('\n6️⃣ Checking if daily summary was already sent...');
    const summaryLogDoc = await db.collection('organizations')
      .doc(orgId)
      .collection('daily_summary_logs')
      .doc(dateStr)
      .get();
    
    if (summaryLogDoc.exists) {
      const logData = summaryLogDoc.data();
      console.log('⚠️ Daily summary already sent today:');
      console.log(`   Sent at: ${logData.sentAt?.toDate()}`);
    } else {
      console.log('✅ No daily summary sent yet today');
    }
    
    // 7. Check Cloud Function logs would be here, but we can't access them from this script
    console.log('\n7️⃣ Recommendations:');
    
    if (adminQuery.docs.length === 0) {
      console.log('❌ No admin users found - daily summaries won\'t send');
    }
    
    if (totalTasks === 0) {
      console.log('❌ No tasks found for today - daily summaries might not trigger');
    }
    
    if (!settingsDoc.exists) {
      console.log('❌ No daily summary settings - function won\'t know when to send');
    }
    
    if (totalTasks > 0 && adminQuery.docs.length > 0 && settingsDoc.exists && !summaryLogDoc.exists) {
      console.log('🤔 Everything looks good - should be sending. Check Cloud Function logs.');
      console.log('💡 Try manually triggering the daily summary function.');
    }
    
    // 8. Show current time vs configured time
    console.log('\n8️⃣ Time Analysis:');
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    console.log(`   Current time: ${currentHour}:${String(currentMinute).padStart(2, '0')}`);
    
    if (settingsDoc.exists) {
      const settings = settingsDoc.data();
      const configuredTime = `${settings.hour}:${String(settings.minute).padStart(2, '0')}`;
      console.log(`   Configured time: ${configuredTime}`);
      
      const configuredMinutes = settings.hour * 60 + settings.minute;
      const currentMinutes = currentHour * 60 + currentMinute;
      
      if (currentMinutes > configuredMinutes) {
        console.log('✅ Current time is past the configured time - summary should have triggered');
      } else {
        const minutesUntil = configuredMinutes - currentMinutes;
        console.log(`⏰ Summary will trigger in ${minutesUntil} minutes`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error debugging daily summary:', error);
  }
}

// Get orgId from command line argument
const orgId = process.argv[2];
if (!orgId) {
  console.log('Usage: node debug_org_daily_summary.js <orgId>');
  process.exit(1);
}

debugOrgDailySummary(orgId).then(() => {
  console.log('\n✅ Debug complete');
  process.exit(0);
}).catch(error => {
  console.error('❌ Script error:', error);
  process.exit(1);
});