// Simple Node.js script to check data availability
// Run with: node check_recent_data.js

const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to set up credentials)
admin.initializeApp({
  // Add your Firebase config here
  credential: admin.credential.applicationDefault(),
  // or use a service account key file
});

const db = admin.firestore();

async function checkRecentData() {
  console.log('🔍 Checking 7-day trend data availability...\n');
  
  const organizationId = 'FErQ4pkcrCovJ7T6L13M';
  const locationId = 'fW45ffBBPar5EaNodDYq';
  
  const today = new Date();
  const results = [];
  
  console.log(`📅 Today: ${today.toISOString().split('T')[0]}`);
  console.log(`🏢 Organization: ${organizationId}`);
  console.log(`📍 Location: ${locationId}\n`);
  
  // Check last 7 days ending with yesterday (exclude today)
  for (let i = 7; i >= 1; i--) {
    const day = new Date(today);
    day.setDate(today.getDate() - i);
    const dayStr = day.toISOString().split('T')[0];
    
    console.log(`📅 Day ${i} ago: ${dayStr}`);
    
    try {
      // Check location-scoped daily_checklists
      const locationQuery = await db
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', dayStr)
        .get();
      
      console.log(`   Location-scoped checklists: ${locationQuery.docs.length}`);
      
      // Check org-scoped daily_checklists as fallback
      const orgQuery = await db
        .collection('organizations')
        .doc(organizationId)
        .collection('daily_checklists')
        .where('date', '==', dayStr)
        .where('locationId', '==', locationId)
        .get();
      
      console.log(`   Org-scoped checklists: ${orgQuery.docs.length}`);
      
      const totalChecklists = locationQuery.docs.length + orgQuery.docs.length;
      results.push({ date: dayStr, checklists: totalChecklists });
      
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}`);
      results.push({ date: dayStr, error: error.message });
    }
  }
  
  console.log('\n📊 SUMMARY:');
  console.log('=' * 50);
  
  let totalChecklists = 0;
  let daysWithData = 0;
  
  for (const result of results) {
    if (result.error) {
      console.log(`${result.date}: ERROR - ${result.error}`);
    } else {
      totalChecklists += result.checklists;
      if (result.checklists > 0) daysWithData++;
      console.log(`${result.date}: ${result.checklists} checklists`);
    }
  }
  
  console.log(`\n🎯 RESULT:`);
  console.log(`   Days with data: ${daysWithData}/7`);
  console.log(`   Total checklists: ${totalChecklists}`);
  
  if (daysWithData === 0) {
    console.log('\n❌ ISSUE IDENTIFIED: No data found for any day in the 7-day window!');
    console.log('   This explains why the dashboard shows zeros.');
    console.log('   The restaurant may not have had shifts scheduled in the past 7 days,');
    console.log('   or checklists may be stored under different identifiers.');
  } else {
    console.log('\n✅ Data exists for recent days.');
    console.log('   The dashboard should be showing this data.');
    console.log('   This suggests a bug in the dashboard query logic.');
  }
  
  process.exit(0);
}

checkRecentData().catch(console.error);