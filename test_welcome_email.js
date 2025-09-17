/**
 * Test script for welcome email functionality
 * Tests the SendGrid template integration for subscription welcome emails
 */

const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com/'
  });
}

async function testWelcomeEmail() {
  try {
    console.log('Testing welcome email functionality...');
    
    // Set SendGrid API key (you'll need to set this in your environment)
    const sendgridApiKey = process.env.SENDGRID_API_KEY;
    if (!sendgridApiKey) {
      console.error('SENDGRID_API_KEY environment variable not set');
      return;
    }
    
    sgMail.setApiKey(sendgridApiKey);
    
    // Test email data
    const testData = {
      firstName: 'John',
      orgName: 'Test Restaurant',
      email: 'test@example.com', // Change this to your email for testing
      temporaryPassword: 'N/A',
      welcomeUrl: 'https://plan-with-hands.web.app/dashboard',
      adminEmail: 'support@planwithhands.com',
    };
    
    const msg = {
      to: testData.email,
      from: 'noreply@em5998.planwithhands.com',
      templateId: 'd-575968e4e0c449f59ca89c1decdc8abc',
      dynamicTemplateData: testData,
    };
    
    console.log('Sending test email to:', testData.email);
    console.log('Using template ID:', msg.templateId);
    
    await sgMail.send(msg);
    console.log('✅ Welcome email sent successfully!');
    
  } catch (error) {
    console.error('❌ Failed to send welcome email:', error);
    if (error.response) {
      console.error('SendGrid error response:', error.response.body);
    }
  }
}

// Run the test
testWelcomeEmail();
