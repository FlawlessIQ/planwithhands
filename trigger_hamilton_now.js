const https = require('https');

async function triggerHamiltonSummary() {
  console.log('🚀 Triggering Hamilton Pork daily summary via HTTP...\n');
  
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

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      console.log(`Status: ${res.statusCode}`);
      
      let responseData = '';
      res.on('data', (d) => {
        responseData += d;
      });
      
      res.on('end', () => {
        console.log('Response:', responseData);
        if (res.statusCode === 200) {
          console.log('\n✅ Function executed successfully!');
          console.log('📧 Daily summary should be sent to jgondevas@gmail.com');
          resolve(responseData);
        } else {
          console.log('\n❌ Function call failed');
          reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
        }
      });
    });
    
    req.on('error', (e) => {
      console.error('Request error:', e);
      reject(e);
    });
    
    req.write(data);
    req.end();
  });
}

triggerHamiltonSummary()
  .then(() => {
    console.log('\n✅ Manual trigger complete');
    process.exit(0);
  })
  .catch(err => {
    console.error('\n❌ Error:', err.message);
    
    // If HTTP call fails due to auth, provide alternative solutions
    console.log('\n💡 Alternative solutions:');
    console.log('1. The scheduled function should run again tomorrow at 8:00 UTC');
    console.log('2. You can manually send the summary from the Flutter app admin dashboard');
    console.log('3. Check if there are any Cloud Scheduler issues in Google Cloud Console');
    
    process.exit(1);
  });