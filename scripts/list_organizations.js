#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function listOrganizations() {
  try {
    console.log('🔍 Listing all organizations...\n');
    
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`📍 Found ${orgsSnapshot.docs.length} organizations:\n`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      console.log(`  ${orgDoc.id}: ${orgData.name || 'Unnamed Organization'}`);
    }
    
    if (orgsSnapshot.docs.length === 0) {
      console.log('  No organizations found.');
    }
    
  } catch (error) {
    console.error(`❌ Error listing organizations:`, error);
  }
}

listOrganizations()
  .then(() => {
    console.log(`\n🎉 Organization list completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 List failed:`, error);
    process.exit(1);
  });
