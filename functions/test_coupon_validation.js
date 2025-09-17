const functions = require('firebase-functions-test')();
const admin = require('firebase-admin');

// Initialize the app if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Import the stripe functions
const stripeModule = require('./stripe_functions');

async function testCouponValidation() {
  console.log('🚀 Testing coupon validation...');
  
  // Test with a known coupon code
  const testCouponCode = 'TEST10'; // Replace with your actual coupon code
  
  try {
    console.log(`Testing coupon code: ${testCouponCode}`);
    
    // Mock the context (you can set auth if needed)
    const mockContext = {
      auth: {
        uid: 'test-user-123'
      }
    };
    
    // Call the validateCoupon function directly
    const result = await stripeModule.validateCoupon({ couponCode: testCouponCode }, mockContext);
    
    console.log('✅ Coupon validation result:');
    console.log(JSON.stringify(result, null, 2));
    
    if (result.success) {
      console.log('Coupon is valid!');
      console.log('Coupon details:', result.coupon);
    } else {
      console.log('Coupon validation failed:', result.error);
    }
    
  } catch (error) {
    console.error('❌ Error testing coupon validation:', error);
    console.error('Error details:', error.message);
    console.error('Error type:', error.type);
    console.error('Error code:', error.code);
  }
}

// Test multiple coupon codes
async function testMultipleCoupons() {
  const testCodes = [
    'TEST10',
    'INVALID123',
    'EXPIRED',
    // Add more test codes here
  ];
  
  for (const code of testCodes) {
    console.log(`\n--- Testing: ${code} ---`);
    try {
      const result = await stripeModule.validateCoupon({ couponCode: code }, { auth: { uid: 'test' } });
      console.log(`Result: ${result.success ? 'VALID' : 'INVALID'}`);
      if (!result.success) console.log(`Error: ${result.error}`);
    } catch (error) {
      console.log(`Exception: ${error.message}`);
    }
  }
}

// Run the test
testCouponValidation()
  .then(() => testMultipleCoupons())
  .then(() => {
    console.log('\nTest completed');
    functions.cleanup();
    process.exit(0);
  })
  .catch((error) => {
    console.error('Test failed:', error);
    functions.cleanup();
    process.exit(1);
  });
