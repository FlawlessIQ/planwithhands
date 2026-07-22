const admin = require('firebase-admin');
const { DailySummaryService } = require('../lib/services/daily_summary_service.dart');

// Simple test script to trigger daily summary for an organization
async function testDailySummary() {
  try {
    console.log('Testing daily summary functionality...');
    
    // Replace with your organization ID
    const orgId = 'test_org_id'; // You'll need to get this from your app
    const targetDate = new Date(); // Today
    
    console.log(`Generating daily summary for org: ${orgId}`);
    console.log(`Target date: ${targetDate.toISOString()}`);
    
    // This would call the Cloud Function
    const functions = require('firebase-functions');
    const callable = functions.httpsCallable('triggerDailySummary');
    
    const result = await callable({
      orgId: orgId,
      targetDate: targetDate.toISOString()
    });
    
    console.log('Daily summary result:', result.data);
    console.log('✅ Daily summary test completed successfully');
    
  } catch (error) {
    console.error('❌ Daily summary test failed:', error);
  }
}

// Run the test
testDailySummary().catch(console.error);