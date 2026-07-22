const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

async function testSendToToken() {
  try {
    console.log('🔔 Testing sendToToken function directly...');
    
    // Test with a fake token first to see if the function is working
    const testToken = 'fake-token-for-testing-function-execution';
    
    const callable = admin.functions().httpsCallable('sendToToken');
    
    try {
      const result = await callable({
        token: testToken,
        title: 'Test Notification',
        body: 'Testing if the sendToToken function works'
      });
      
      console.log('✅ sendToToken function executed:', result.data);
    } catch (error) {
      console.log('❌ sendToToken function error:', error.message);
      // This is expected to fail with a fake token, but at least we know the function works
      if (error.message.includes('registration-token-not-registered') || 
          error.message.includes('invalid-registration-token')) {
        console.log('✅ Function is working (token validation failed as expected)');
      }
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

testSendToToken();
