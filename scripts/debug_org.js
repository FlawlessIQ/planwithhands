#!/usr/bin/env node

/**
 * Debug script to check organization and location data
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function debugOrganization(orgId) {
  try {
    console.log(`🔍 Checking organization: ${orgId}`);
    
    // Check if organization document exists
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    console.log(`   Organization exists: ${orgDoc.exists}`);
    
    if (orgDoc.exists) {
      console.log('   Organization data:', orgDoc.data());
    }
    
    // Check locations
    console.log('\n📍 Checking locations...');
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
      
    console.log(`   Found ${locationsSnapshot.docs.length} locations:`);
    locationsSnapshot.docs.forEach(doc => {
      console.log(`   - ${doc.id}: ${JSON.stringify(doc.data())}`);
    });
    
    // Check checklist templates
    console.log('\n📋 Checking checklist templates...');
    const templatesSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .get();
      
    console.log(`   Found ${templatesSnapshot.docs.length} checklist templates:`);
    templatesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${doc.id}: "${data.name || data.checklistName}" (locationIds: [${(data.locationIds || []).join(', ')}])`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Get org ID from command line or use the provided one
const orgId = process.argv[2] || 'vnE0olvi1Tswjtdb19MI';
debugOrganization(orgId).then(() => process.exit(0));
