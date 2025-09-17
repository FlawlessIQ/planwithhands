const functions = require('firebase-functions');
const stripe = require('stripe')(functions.config().stripe.secret);

async function testSpecificCoupon() {
  console.log('🔍 Testing the actual coupon: P9zgLhXD');
  
  try {
    const coupon = await stripe.coupons.retrieve('P9zgLhXD');
    console.log('Coupon details:', JSON.stringify(coupon, null, 2));
    
    // Test validation logic
    const isValid = coupon && 
                   !coupon.deleted && 
                   (!coupon.redeem_by || coupon.redeem_by * 1000 > Date.now()) &&
                   (!coupon.max_redemptions || !coupon.times_redeemed || coupon.times_redeemed < coupon.max_redemptions);
    
    console.log(`Validation result: ${isValid ? 'VALID' :'INVALID'}`);
    
    if (isValid) {
      console.log('✅ This coupon should work in your app!');
    } else {
      console.log('❌ This coupon would be rejected by validation logic');
    }
    
  } catch (error) {
    console.error('Error testing coupon:', error.message);
  }
}

testSpecificCoupon();
