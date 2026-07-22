const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = new Firestore({ 
  databaseId: 'planwithhands',
  projectId: 'plan-with-hands'
});

async function manuallyTriggerHamiltonSummary() {
  console.log('\n🚀 Manually triggering Hamilton Pork daily summary for October 14, 2025...\n');
  
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const dateStr = '2025-10-14';
    
    // Step 1: Check if already sent
    console.log('1. Checking if summary was already sent today...');
    const logDoc = await db
      .collection('organizations')
      .doc(orgId)
      .collection('daily_summary_logs')
      .doc(dateStr)
      .get();
    
    if (logDoc.exists) {
      console.log('   ✅ Summary was already sent today');
      console.log('   If you need to resend, you can delete the log document first');
      return;
    } else {
      console.log('   ❌ No summary sent today - proceeding with manual trigger');
    }
    
    // Step 2: Use Firebase CLI to call the function directly
    console.log('\n2. Manual trigger options:');
    console.log('   Option A: Use Firebase CLI (recommended):');
    console.log('   firebase functions:shell');
    console.log('   > triggerDailySummary({orgId: "FErQ4pkcrCovJ7T6L13M", targetDate: "2025-10-14"})');
    
    console.log('\n   Option B: Use the Flutter app:');
    console.log('   - Log in as an admin user for Hamilton Pork');
    console.log('   - Go to the admin dashboard');
    console.log('   - Look for a "Send Daily Summary" or "Manual Trigger" button');
    
    console.log('\n   Option C: Call the HTTP endpoint (requires authentication):');
    console.log('   POST https://us-central1-plan-with-hands.cloudfunctions.net/triggerDailySummary');
    console.log('   Body: {"data": {"orgId": "FErQ4pkcrCovJ7T6L13M", "targetDate": "2025-10-14"}}');
    
    // Step 3: Alternative - simulate the function locally
    console.log('\n🔧 Alternative: I can simulate the daily summary generation...');
    console.log('   This would check the data and show what the summary should contain,');
    console.log('   but won\'t actually send the email.');
    
    // Check if there's data for today
    console.log('\n3. Checking if there\'s data for today...');
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    let totalChecklists = 0;
    for (const locDoc of locationsSnapshot.docs) {
      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locDoc.id)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .get();
      
      totalChecklists += checklistsSnapshot.size;
    }
    
    console.log(`   Checklists found for ${dateStr}: ${totalChecklists}`);
    
    if (totalChecklists > 0) {
      console.log('   ✅ There is data for today - summary should be sent');
    } else {
      console.log('   ⚠️  No checklists found for today - summary would be empty');
    }
    
  } catch (error) {
    console.error('❌ Error during manual trigger setup:', error);
  }
}

manuallyTriggerHamiltonSummary().then(() => {
  console.log('\n✅ Manual trigger guidance complete');
  console.log('\n💡 Recommendation: Use Firebase CLI option for immediate results');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});