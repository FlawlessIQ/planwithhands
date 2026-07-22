const { initializeApp } = require('firebase-admin/app');
const { getFunctions } = require('firebase-admin/functions');

async function testEmail() {
  try {
    console.log('Testing email delivery to con.lawless@gmail.com...');
    
    const response = await fetch('https://us-central1-plan-with-hands.cloudfunctions.net/testSendEmail', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        data: {
          email: 'con.lawless@gmail.com',
          orgId: 'RvLcop2cMGQCXLFlWH3O'
        }
      })
    });
    
    const result = await response.json();
    console.log('Response:', result);
    
  } catch (error) {
    console.error('Error:', error);
  }
}

testEmail();