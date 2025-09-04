// Manual script to generate today's data
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./firebase_config.js');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://plan-with-hands.firebaseio.com'
});

const { generateForOrgDate } = require('./lib/dailyGenerator');

// Get today's date in YYYY-MM-DD format
const today = new Date();
const dateString = today.getFullYear() + '-' + 
  String(today.getMonth() + 1).padStart(2, '0') + '-' + 
  String(today.getDate()).padStart(2, '0');

console.log(`Generating data for organization vnE0olvi1Tswjtdb19MI on ${dateString}`);

// Generate data for your organization
generateForOrgDate('vnE0olvi1Tswjtdb19MI', dateString)
  .then(() => {
    console.log('✅ Successfully generated today\'s data!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Error generating data:', error);
    process.exit(1);
  });
