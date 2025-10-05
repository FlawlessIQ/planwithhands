#!/usr/bin/env node

/**
 * Find the correct organization ID
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function findOrganizations() {
  console.log('🔍 Finding organizations...');
  
  try {
    // List all organizations
    const orgsSnap = await db.collection('organizations').get();
    console.log(`📊 Found ${orgsSnap.docs.length} organizations`);
    
    for (const orgDoc of orgsSnap.docs) {
      const orgData = orgDoc.data();
      console.log(`\n🏢 Org ID: ${orgDoc.id}`);
      console.log(`   Name: ${orgData.name || orgData.organizationName || 'No name'}`);
      console.log(`   Type: ${orgData.type || 'No type'}`);
      
      // Check if this looks like the Hands organization
      const name = (orgData.name || orgData.organizationName || '').toLowerCase();
      if (name.includes('hands') || name.includes('test') || name.includes('demo')) {
        console.log(`   ⭐ POTENTIAL MATCH for Hands app`);
        
        // Check locations in this org
        const locationsSnap = await db
          .collection('organizations')
          .doc(orgDoc.id)
          .collection('locations')
          .limit(3)
          .get();
        
        console.log(`   📍 Has ${locationsSnap.docs.length} locations`);
        for (const locDoc of locationsSnap.docs) {
          const locData = locDoc.data();
          console.log(`      - ${locData.locationName || locDoc.id}`);
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error finding organizations:', error);
  }
}

// Run the search
findOrganizations().then(() => {
  console.log('🏁 Search complete');
  process.exit(0);
});