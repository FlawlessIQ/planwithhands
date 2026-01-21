const sgMail = require('@sendgrid/mail');

async function testWelcomeEmail() {
  try {
    console.log('Testing welcome email functionality...');
    
    // Set SendGrid API key
    const sendgridApiKey = process.env.SENDGRID_API_KEY;
    sgMail.setApiKey(sendgridApiKey);
    
    // Test email data
    const testData = {
      firstName: 'John',
      orgName: 'Test Restaurant',
      email: 'conorlawless@gmail.com', // Changed to your email for testing
      temporaryPassword: 'N/A',
      welcomeUrl: 'https://plan-with-hands.web.app/dashboard',
      adminEmail: 'support@planwithhands.com',
    };
    
    const msg = {
      to: testData.email,
      from: 'noreply@em5998.planwithhands.com',
      templateId: 'd-2132096e57f4469681694bf926fefd95',
      dynamicTemplateData: testData,
    };
    
    console.log('Sending test email to:', testData.email);
    console.log('Using template ID:', msg.templateId);
    console.log('Template data:', JSON.stringify(testData, null, 2));
    
    const result = await sgMail.send(msg);
    console.log('✅ Welcome email sent successfully!');
    console.log('SendGrid response status:', result[0].statusCode);
    
  } catch (error) {
    console.error('❌ Failed to send welcome email:', error);
    if (error.response) {
      console.error('SendGrid error response:', error.response.body);
    }
  }
}

// Run the test
testWelcomeEmail();
