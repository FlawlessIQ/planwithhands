const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getFunctions } = require('firebase-admin/functions');

// Initialize Firebase Admin
const app = initializeApp({
  projectId: 'plan-with-hands'
});

const functions = getFunctions(app);

async function testWebhook() {
  try {
    console.log('Calling testWebhookManual function...');
    
    const callable = functions.httpsCallable('testWebhookManual');
    const result = await callable({});
    
    console.log('Function result:', result.data);
  } catch (error) {
    console.error('Error calling function:', error);
  }
}

testWebhook();