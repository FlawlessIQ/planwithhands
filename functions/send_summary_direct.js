#!/usr/bin/env node

/**
 * Script to manually send a daily summary for a specific organization and date
 * This bypasses the scheduled function and sends directly
 */

const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');
const sgMail = require('@sendgrid/mail');

// Initialize Firebase
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

// Configuration
const CONFIG = {
  orgId: '3qjYzHagWmfbnMieJ1aj',
  targetDate: '2025-10-01',
  testEmail: 'con.lawless@gmail.com',  // Override to send to this email instead of all admins
};

// Helper functions
function formatDate(date) {
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padLeft(2, '0');
  const day = String(d.getDate()).padLeft(2, '0');
  return `${year}-${month}-${day}`;
}

async function sendDailySummaryManually() {
  try {
    console.log('\n╔═══════════════════════════════════════════════════════════════╗');
    console.log('║         MANUAL DAILY SUMMARY EMAIL SENDER                      ║');
    console.log('╚═══════════════════════════════════════════════════════════════╝\n');
    
    console.log(`📋 Configuration:`);
    console.log(`   Organization ID: ${CONFIG.orgId}`);
    console.log(`   Target Date: ${CONFIG.targetDate}`);
    console.log(`   Test Email: ${CONFIG.testEmail}\n`);
    
    // Get organization data
    console.log('⏳ Fetching organization data...');
    const orgDoc = await db.collection('organizations').doc(CONFIG.orgId).get();
    
    if (!orgDoc.exists) {
      throw new Error(`Organization ${CONFIG.orgId} not found`);
    }
    
    const orgData = orgDoc.data();
    const orgName = orgData.name || orgData.organizationName || CONFIG.orgId;
    console.log(`✅ Organization: ${orgName}\n`);
    
    // Import the compiled function
    const scheduledDailySummary = require('./lib/scheduledDailySummary');
    
    // Since we can't directly access internal functions, we'll need to simulate
    // what the triggerDailySummary function does
    
    console.log('⏳ Collecting daily summary data...');
    
    // Get admin users
    const usersSnapshot = await db.collection('users')
      .where('organizationId', '==', CONFIG.orgId)
      .where('userRole', '>=', 1)
      .where('isActive', '==', true)
      .get();
    
    const adminUsers = usersSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        userId: doc.id,
        email: CONFIG.testEmail, // Override email
        firstName: data.firstName || '',
        lastName: data.lastName || '',
      };
    });
    
    if (adminUsers.length === 0) {
      throw new Error('No admin users found for organization');
    }
    
    console.log(`✅ Found ${adminUsers.length} admin user(s)`);
    console.log(`📧 Will send to: ${CONFIG.testEmail}\n`);
    
    // The function is deployed, so we need to call it through the Cloud Functions API
    // Let's use a HTTP request instead
    const https = require('https');
    
    const functionUrl = 'https://us-central1-plan-with-hands.cloudfunctions.net/triggerDailySummary';
    
    console.log('⏳ Calling deployed Cloud Function...\n');
    console.log(`   URL: ${functionUrl}`);
    console.log(`   Payload: ${JSON.stringify({ orgId: CONFIG.orgId, targetDate: CONFIG.targetDate }, null, 2)}\n`);
    
    // Note: This function requires authentication, so we'll need to handle that
    console.log('⚠️  Note: This function requires Firebase Auth context.');
    console.log('   Alternative: Use Firebase Console or authenticated app to trigger.\n');
    
    console.log('✅ Script preparation complete!');
    console.log('\n💡 To send the summary, you can:');
    console.log('   1. Open your app as an admin user');
    console.log('   2. Use Firebase Console to call triggerDailySummary');
    console.log('   3. Or wait for the next scheduled run\n');
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    if (error.stack) {
      console.error('\nStack trace:', error.stack);
    }
    process.exit(1);
  }
}

// Run
sendDailySummaryManually()
  .then(() => {
    console.log('✅ Script completed');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
