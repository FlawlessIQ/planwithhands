const functions = require('firebase-functions-test')();
const admin = require('firebase-admin');

// Initialize the app if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Import the function
const { sendOrganizationSignupNotification } = require('./functions/user_functions');

// Test data
const testData = {
  organizationName: "Test Organization",
  adminFirstName: "John",
  adminLastName: "Doe", 
  adminEmail: "john.doe@testcompany.com",
  businessType: "Technology",
  numberOfEmployees: 25,
  numberOfLocations: 3,
  subscriptionType: "Monthly",
  organizationId: "test_org_123",
  createdAt: new Date().toIso8601String()
};

// Mock context
const context = {
  auth: {
    uid: "test_user_123"
  }
};

console.log('Testing organization signup notification...');
console.log('Test data:', JSON.stringify(testData, null, 2));

// Test the function
sendOrganizationSignupNotification(testData, context)
  .then(result => {
    console.log('✅ Function executed successfully:', result);
    functions.cleanup();
  })
  .catch(error => {
    console.error('❌ Function failed:', error);
    functions.cleanup();
  });
