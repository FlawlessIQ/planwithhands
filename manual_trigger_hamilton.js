const admin = require('firebase-admin');
const { CloudFunctionsServiceClient } = require('@google-cloud/functions');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

async function triggerHamiltonSummary() {
  try {
    console.log('🚀 Manually triggering daily summary for Hamilton Pork...');
    console.log('   Organization ID: FErQ4pkcrCovJ7T6L13M');
    console.log('   Date: 2025-10-14');
    
    // Use Firebase Functions client
    const { CloudFunctions } = require('@google-cloud/functions');
    const client = new CloudFunctions();
    
    // Alternative: Use HTTP request to call the function directly
    const https = require('https');
    const data = JSON.stringify({
      data: {
        orgId: 'FErQ4pkcrCovJ7T6L13M',
        targetDate: '2025-10-14'
      }
    });
    
    const options = {
      hostname: 'us-central1-plan-with-hands.cloudfunctions.net',
      port: 443,
      path: '/triggerDailySummary',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length,
      }
    };
    
    console.log('Calling function via HTTPS...');
    
    const req = https.request(options, (res) => {
      console.log(`Status: ${res.statusCode}`);
      console.log(`Headers: ${JSON.stringify(res.headers)}`);
      
      let responseData = '';
      res.on('data', (d) => {
        responseData += d;
      });
      
      res.on('end', () => {
        console.log('Response:', responseData);
        process.exit(0);
      });
    });
    
    req.on('error', (e) => {
      console.error('Request error:', e);
      process.exit(1);
    });
    
    req.write(data);
    req.end();
    
  } catch (error) {
    console.error('\n❌ Error calling function:', error);
    process.exit(1);
  }
}
}

triggerHamiltonSummary().then(() => {
  console.log('\n✅ Manual trigger complete');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});