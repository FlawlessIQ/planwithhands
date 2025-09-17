const functions = require('firebase-functions');
const stripe = require('stripe')(functions.config().stripe.secret);

async function testStripeCoupons() {
  console.log('🔍 Testing Stripe coupon validation directly...');
  
  // List all coupons first to see what's available
  try {
    console.log('\n📋 Listing available coupons:');
    const coupons = await stripe.coupons.list({ limit: 10 });
    console.log(`Found ${coupons.data.length} coupons:`);
    
    coupons.data.forEach(coupon => {
      console.log(`- ${coupon.id}: ${coupon.name || 'No name'} (${coupon.percent_off ? coupon.percent_off + '%' : '$' + coupon.amount_off/100} off)`);
    });
    
    // Test with specific coupon codes
    const testCodes = ['TEST10', 'SAVE20', 'WELCOME', '10PERCENT'];
    
    for (const code of testCodes) {
      try {
        console.log(`\n🧪 Testing coupon: ${code}`);
        const coupon = await stripe.coupons.retrieve(code);
        console.log(`✅ Found: ${coupon.name || coupon.id}`);
        console.log(`   Percent off: ${coupon.percent_off}%`);
        console.log(`   Amount off: $${coupon.amount_off ? coupon.amount_off/100 : 0}`);
        console.log(`   Valid: ${!coupon.deleted}`);
        console.log(`   Times redeemed: ${coupon.times_redeemed || 0}`);
        console.log(`   Max redemptions: ${coupon.max_redemptions || 'unlimited'}`);
        
        // Test validation logic
        const isValid = coupon && 
                       !coupon.deleted && 
                       (!coupon.redeem_by || coupon.redeem_by * 1000 > Date.now()) &&
                       (!coupon.max_redemptions || !coupon.times_redeemed || coupon.times_redeemed < coupon.max_redemptions);
        
        console.log(`   Our validation result: ${isValid ? 'VALID' : 'INVALID'}`);
        
      } catch (error) {
        console.log(`❌ Error: ${error.message}`);
      }
    }
    
  } catch (error) {
    console.error('Error listing coupons:', error.message);
  }
}

testStripeCoupons();
