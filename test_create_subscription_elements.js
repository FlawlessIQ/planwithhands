const axios = require('axios');

async function testCreateSubscriptionElements() {
  try {
    console.log('Testing createSubscriptionElements function via HTTP...');
    
    // Test data
    const testData = {
      data: {
        orgId: 'test_org_' + Date.now(),
        priceId: 'price_1QGN8RCOdg37MrElQiKXoXJz', // Monthly price ID from your system
        quantity: 1,
        email: 'test@example.com',
        couponId: 'TEST100'
      }
    };
    
    console.log('Test data:', testData);
    
    // Call the function via HTTP (simulates what the Flutter app does)
    const response = await axios.post(
      'https://us-central1-hands-app-c0658.cloudfunctions.net/createSubscriptionElements',
      testData,
      {
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );
    
    console.log('Function result:', response.data);
    
    if (response.data && response.data.subscription) {
      console.log('✅ Function executed successfully');
      console.log('Subscription ID:', response.data.subscription.id);
      console.log('Customer ID:', response.data.subscription.customer);
      console.log('Status:', response.data.subscription.status);
    } else {
      console.log('❌ Function returned unexpected result');
    }
    
  } catch (error) {
    console.error('❌ Error testing function:', error.response?.data || error.message);
  }
}

testCreateSubscriptionElements();