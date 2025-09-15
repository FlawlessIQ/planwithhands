// Simple test script to verify the organization signup notification function
const admin = require('firebase-admin');
const functions = require('firebase-functions');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

// Import the user functions
const userFunctions = require('./functions/user_functions.js');

async function testOrganizationSignupNotification() {
  console.log('🚀 Testing organization signup notification function...');
  
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

  const mockContext = {
    auth: {
      uid: "test_user_123"
    }
  };

  console.log('📧 Test data:', JSON.stringify(testData, null, 2));
  
  try {
    const result = await userFunctions.sendOrganizationSignupNotification(testData, mockContext);
    console.log('✅ Success! Function result:', result);
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('Full error:', error);
  }
}

// Run the test
testOrganizationSignupNotification();
