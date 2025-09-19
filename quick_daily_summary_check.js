const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();

async function quickDailySummaryCheck() {
  console.log('🔍 Quick Daily Summary Status Check for September 18, 2025\n');
  
  try {
    // Get first organization
    const orgsSnapshot = await db.collection('organizations').limit(1).get();
    if (orgsSnapshot.empty) {
      console.log('❌ No organizations found');
      return;
    }
    
    const orgDoc = orgsSnapshot.docs[0];
    const orgId = orgDoc.id;
    const orgData = orgDoc.data();
    console.log('📋 Organization:', orgData.name || orgId);
    console.log('📋 Organization ID:', orgId);
    
    // Check admin users (using userRole field)
    const adminUsers = await db.collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', 'in', [1, 2])
      .where('isActive', '==', true)
      .get();
      
    console.log('👥 Admin/Manager users:', adminUsers.size);
    adminUsers.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.firstName || ''} ${data.lastName || ''} (${data.email || doc.id}) - Role: ${data.userRole}`);
    });
    
    // Check today's summary log (September 18, 2025)
    const dateStr = '2025-09-18';
    
    const logDoc = await db.collection('organizations')
      .doc(orgId)
      .collection('daily_summary_logs')
      .doc(dateStr)
      .get();
      
    console.log(`\n📅 Summary sent for ${dateStr}:`, logDoc.exists);
    if (logDoc.exists) {
      const logData = logDoc.data();
      console.log('   Sent at:', logData.sentAt?.toDate());
    }
    
    // Check if there was task data for today
    const tasksSnapshot = await db.collectionGroup('daily_checklists')
      .where('date', '==', dateStr)
      .limit(5)
      .get();
      
    console.log(`📋 Task data exists for ${dateStr}:`, !tasksSnapshot.empty);
    console.log(`📋 Number of checklists found:`, tasksSnapshot.size);
    
    // Check recent notifications for admin users
    if (!adminUsers.empty) {
      const firstAdminId = adminUsers.docs[0].id;
      const notifications = await db.collection('userNotifications')
        .doc(firstAdminId)
        .collection('notifications')
        .where('type', '==', 'daily_summary')
        .orderBy('createdAt', 'desc')
        .limit(3)
        .get();
        
      console.log(`\n📬 Recent daily summary notifications for admin:`, notifications.size);
      notifications.forEach(doc => {
        const data = doc.data();
        console.log(`   - ${data.createdAt?.toDate()}: ${data.title}`);
      });
    }
    
    console.log('\n⏰ Current time:', new Date());
    console.log('📍 Scheduled to run: 21:00 UTC daily');
    console.log('📍 Current UTC time:', new Date().toISOString());
    
    // Check recent function execution logs
    console.log('\n🔧 The scheduledDailySummary function should have run last at 21:00 UTC on September 18');
    console.log('   If no summary was sent but data exists, there may be an issue with:');
    console.log('   1. Function execution (check Firebase Console logs)');
    console.log('   2. Timezone logic (currently checking 20-23 hours local time)');
    console.log('   3. Data processing logic (empty content check)');
    console.log('   4. Notification delivery system');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

quickDailySummaryCheck().then(() => {
  console.log('\n✅ Check completed');
  process.exit(0);
}).catch(error => {
  console.error('💥 Failed:', error);
  process.exit(1);
});