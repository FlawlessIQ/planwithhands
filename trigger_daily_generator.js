const admin = require('firebase-admin');

// Initialize with the project credentials
const serviceAccount = require('./planwithhands_service_key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://plan-with-hands.firebaseio.com"
});

const db = admin.firestore();

// Set the database to use planwithhands
db.settings({
  databaseId: 'planwithhands'
});

async function triggerDailyGenerator() {
  try {
    console.log("Triggering daily generator for today's date...");
    
    // Get today's date in YYYY-MM-DD format
    const today = new Date();
    const dateString = today.toISOString().split('T')[0];
    
    console.log(`Running daily generator for date: ${dateString}`);
    
    // Make HTTP request to trigger the Cloud Function
    const functions = require('firebase-functions');
    const https = require('https');
    
    // Alternative: Call the scheduled function trigger URL
    const triggerUrl = 'https://us-central1-plan-with-hands.cloudfunctions.net/dailyGenerator';
    
    const options = {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const req = https.request(triggerUrl, options, (res) => {
      console.log(`Status: ${res.statusCode}`);
      res.on('data', (data) => {
        console.log('Response:', data.toString());
      });
      res.on('end', () => {
        console.log('Daily generator triggered successfully');
        process.exit(0);
      });
    });
    
    req.on('error', (error) => {
      console.error('Error triggering daily generator:', error);
      process.exit(1);
    });
    
    req.end();
    
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

triggerDailyGenerator();