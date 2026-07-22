// Simple Node.js script to check daily summary related data in Firestore
const admin = require('firebase-admin');

// Initialize Firebase Admin (using default credentials)
admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function debugDailySummary() {
  console.log('🔍 Starting daily summary debug...');
  
  try {
    // 1. Check organizations
    console.log('\n📊 Step 1: Checking organizations...');
    const orgsSnapshot = await db.collection('organizations').limit(3).get();
    console.log(`Found ${orgsSnapshot.docs.length} organizations`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      console.log(`\n🏢 Organization: ${orgData.name || orgData.organizationName || 'Unknown'} (${orgId})`);
      
      // Check admin users
      const adminQuery = await db
        .collection('users')
        .where('organizationId', '==', orgId)
        .where('userRole', 'in', [1, 2])
        .where('isActive', '==', true)
        .get();
      
      console.log(`   Admin users: ${adminQuery.docs.length}`);
      
      // Check locations and their timezones
      const locationsQuery = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .limit(3)
        .get();
      
      console.log(`   Locations: ${locationsQuery.docs.length}`);
      for (const locDoc of locationsQuery.docs) {
        const locData = locDoc.data();
        console.log(`     - ${locData.locationName || 'Unknown'}: timezone = ${locData.timezone || 'NOT SET'}`);
      }
      
      // Check daily summary logs for last 7 days
      console.log('   Daily summary logs (last 7 days):');
      const now = new Date();
      for (let i = 0; i < 7; i++) {
        const date = new Date(now);
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0]; // YYYY-MM-DD
        
        const logDoc = await db
          .collection('organizations')
          .doc(orgId)
          .collection('daily_summary_logs')
          .doc(dateStr)
          .get();
        
        if (logDoc.exists) {
          const logData = logDoc.data();
          console.log(`     ✅ ${dateStr} - Sent at: ${logData.sentAt?.toDate()}`);
        } else {
          console.log(`     ❌ ${dateStr} - No summary sent`);
        }
      }
      
      // Check recent notifications
      const recentNotifs = await db
        .collection('organizations')
        .doc(orgId)
        .collection('notifications')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get();
      
      console.log(`   Recent notifications: ${recentNotifs.docs.length}`);
      for (const notifDoc of recentNotifs.docs) {
        const notifData = notifDoc.data();
        const title = notifData.title || 'No title';
        const isDailySummary = title.includes('Daily Notes Summary') || title.includes('Daily Summary');
        const createdAt = notifData.createdAt?.toDate();
        console.log(`     ${isDailySummary ? '📋' : '📝'} ${title} (${createdAt || 'No date'})`);
      }
    }
    
    // 2. Check recent function logs
    console.log('\n⚡ Step 2: Recent function execution summary...');
    console.log('From the Firebase logs we can see:');
    console.log('- scheduledDailyGenerator is running hourly but skipping locations due to missing timezones');
    console.log('- This function only creates checklists, not daily summaries');
    console.log('- Daily summaries should be triggered by client-side DailyBackgroundService');
    
    console.log('\n✅ Debug completed!');
    
  } catch (error) {
    console.error('❌ Debug failed:', error);
  }
  
  process.exit(0);
}

debugDailySummary();
