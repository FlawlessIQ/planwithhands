const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkAllOrgsSummaries() {
  console.log('\n=== Checking Daily Summary Status for All Organizations ===\n');
  
  try {
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    
    console.log(`Total organizations: ${orgsSnapshot.size}\n`);
    
    let enabledCount = 0;
    let disabledCount = 0;
    let recentlySent = 0;
    let notSentRecently = 0;
    
    const results = [];
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.organizationName || orgData.name || 'Unknown';
      const dailySettings = orgData.dailySummarySettings || {};
      const enabled = dailySettings.enabled || false;
      
      if (!enabled) {
        disabledCount++;
        continue;
      }
      
      enabledCount++;
      
      // Check recent summary logs (last 7 days)
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      
      const logsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('daily_summary_logs')
        .where('sentAt', '>=', sevenDaysAgo)
        .orderBy('sentAt', 'desc')
        .limit(7)
        .get();
      
      const logCount = logsSnapshot.size;
      const lastLog = logsSnapshot.docs[0]?.data();
      const lastSent = lastLog ? new Date(lastLog.sentAt._seconds * 1000) : null;
      
      const result = {
        orgId,
        orgName,
        timezone: orgData.timezone || 'Unknown',
        summaryTime: `${dailySettings.hour || 'N/A'}:${String(dailySettings.minute || 0).padStart(2, '0')}`,
        summaryPeriod: dailySettings.summaryPeriod || 'calendar-day',
        logsLast7Days: logCount,
        lastSent: lastSent ? lastSent.toISOString() : 'Never',
        daysSinceLastSent: lastSent ? Math.floor((Date.now() - lastSent.getTime()) / (1000 * 60 * 60 * 24)) : 999
      };
      
      results.push(result);
      
      if (result.daysSinceLastSent <= 1) {
        recentlySent++;
      } else {
        notSentRecently++;
      }
    }
    
    // Sort by days since last sent (descending - most problematic first)
    results.sort((a, b) => b.daysSinceLastSent - a.daysSinceLastSent);
    
    console.log('=== SUMMARY ===');
    console.log(`Total organizations: ${orgsSnapshot.size}`);
    console.log(`Daily summaries enabled: ${enabledCount}`);
    console.log(`Daily summaries disabled: ${disabledCount}`);
    console.log(`Sent in last 1 day: ${recentlySent}`);
    console.log(`NOT sent in last 1 day: ${notSentRecently}\n`);
    
    console.log('=== ORGANIZATIONS WITH DAILY SUMMARIES ENABLED ===\n');
    
    for (const result of results) {
      const status = result.daysSinceLastSent === 0 ? '✅' : 
                     result.daysSinceLastSent === 1 ? '⚠️' :
                     result.daysSinceLastSent < 7 ? '❌' : '🔴';
      
      console.log(`${status} ${result.orgName} (${result.orgId})`);
      console.log(`   Time: ${result.summaryTime} ${result.timezone}`);
      console.log(`   Period: ${result.summaryPeriod}`);
      console.log(`   Last 7 days: ${result.logsLast7Days} summaries sent`);
      console.log(`   Last sent: ${result.lastSent}`);
      console.log(`   Days since: ${result.daysSinceLastSent === 999 ? 'Never' : result.daysSinceLastSent}\n`);
    }
    
    console.log('\nLEGEND:');
    console.log('✅ Sent today');
    console.log('⚠️  Sent yesterday');
    console.log('❌ Sent 2-6 days ago');
    console.log('🔴 Not sent in 7+ days or never');
    
  } catch (error) {
    console.error('Error checking organizations:', error);
  }
}

checkAllOrgsSummaries()
  .then(() => {
    console.log('\nCheck complete');
    process.exit(0);
  })
  .catch(error => {
    console.error('Error:', error);
    process.exit(1);
  });
