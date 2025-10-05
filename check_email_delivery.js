const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Admin SDK with application default credentials
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = new Firestore({ 
  databaseId: 'planwithhands',
  projectId: 'plan-with-hands'
});

const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

async function checkEmailIssues() {
  console.log('\n=== EMAIL DELIVERY CHECK ===\n');
  
  try {
    // Get all admin users for this org
    console.log('1. ADMIN USERS IN ORGANIZATION:');
    const usersSnapshot = await db.collection('users')
      .where('organizationId', '==', ORG_ID)
      .where('userRole', 'in', [1, 2])
      .where('isActive', '==', true)
      .get();
    
    console.log(`   Found ${usersSnapshot.size} admin users:\n`);
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      console.log(`   ✅ ${userData.firstName} ${userData.lastName}`);
      console.log(`      Email: ${userData.email}`);
      console.log(`      Role: ${userData.userRole === 2 ? 'Owner/Admin' : 'Manager'}`);
      console.log(`      User ID: ${userDoc.id}\n`);
    }
    
    // Check recent logs with timestamps
    console.log('2. RECENT SUMMARY SEND LOGS (Last 3 days):');
    const today = new Date();
    for (let i = 0; i < 3; i++) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      const dateStr = date.getFullYear() + '-' +
                     String(date.getMonth() + 1).padStart(2, '0') + '-' +
                     String(date.getDate()).padStart(2, '0');
      
      const logDoc = await db.collection('organizations').doc(ORG_ID)
        .collection('daily_summary_logs').doc(dateStr).get();
      
      if (logDoc.exists) {
        const logData = logDoc.data();
        const sentAt = logData.sentAt?.toDate();
        console.log(`\n   Date: ${dateStr}`);
        console.log(`   Sent At: ${sentAt?.toISOString()}`);
        console.log(`   Sent At (Local): ${sentAt?.toLocaleString('en-US', { timeZone: 'America/New_York' })}`);
      }
    }
    
    // Check if SendGrid is configured (this will fail without service account, but we can check logs)
    console.log('\n3. SENDGRID CONFIGURATION CHECK:');
    console.log('   Note: SendGrid API key is configured in Firebase Functions environment');
    console.log('   To verify email delivery, check SendGrid dashboard at:');
    console.log('   https://app.sendgrid.com/email_activity');
    console.log('');
    console.log('   Search for recipient: jgondevas@gmail.com');
    console.log('   Date range: Last 7 days');
    console.log('   Check for:');
    console.log('   - Delivered status');
    console.log('   - Bounced emails');
    console.log('   - Spam complaints');
    console.log('');
    
    // Get org data to show what would be sent
    const orgDoc = await db.collection('organizations').doc(ORG_ID).get();
    const orgData = orgDoc.data();
    const orgName = orgData.organizationName || orgData.name || 'Unknown';
    
    console.log('4. EMAIL DETAILS:');
    console.log(`   From: noreply@planwithhands.com (Hands App)`);
    console.log(`   To: All ${usersSnapshot.size} admin users listed above`);
    console.log(`   Subject Pattern: [Emoji] Daily Summary: ${orgName} - [Date] ([X]% Complete)`);
    console.log(`   Template ID: d-b24a7a9c340046d3a5429f203c19470e`);
    console.log('');
    
    console.log('5. TROUBLESHOOTING STEPS:');
    console.log('');
    console.log('   If user is not receiving emails, check:');
    console.log('');
    console.log('   ✓ Spam/Junk folder - Check for emails from noreply@planwithhands.com');
    console.log('   ✓ Gmail filters - User may have auto-archived or filtered');
    console.log('   ✓ SendGrid activity - Check delivery status in SendGrid dashboard');
    console.log('   ✓ Email blocks - Gmail may be blocking if domain reputation is low');
    console.log('');
    console.log('   To manually trigger a test email:');
    console.log('   Run: node trigger_daily_summary.js');
    console.log('');
    
  } catch (error) {
    console.error('Error:', error);
  }
}

checkEmailIssues().then(() => {
  console.log('✅ Check complete\n');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
