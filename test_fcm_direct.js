const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

async function testFCMDirect() {
    console.log('Testing FCM directly...');
    
    try {
        // Test with a fake token to see what error we get
        const fakeToken = 'fake_token_for_testing';
        
        const message = {
            notification: {
                title: 'Test FCM Direct',
                body: 'Testing FCM connectivity'
            },
            token: fakeToken
        };
        
        console.log('Attempting to send via FCM...');
        const response = await admin.messaging().send(message);
        console.log('FCM response:', response);
        
    } catch (error) {
        console.log('FCM Error Details:');
        console.log('Error code:', error.code);
        console.log('Error message:', error.message);
        console.log('Error toString:', error.toString());
        
        if (error.errorInfo) {
            console.log('Error info:', JSON.stringify(error.errorInfo, null, 2));
        }
        
        // Check if this is an HTTP error
        if (error.httpResponse) {
            console.log('HTTP Response status:', error.httpResponse.status);
            console.log('HTTP Response data:', error.httpResponse.data);
        }
    }
}

testFCMDirect();
