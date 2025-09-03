#!/usr/bin/env node

/**
 * Script to find all organizations in the database
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function findAllOrganizations() {
  try {
    console.log('🔍 Searching for all organizations...\n');
    
    const orgsSnapshot = await db.collection('organizations').get();
    
    if (orgsSnapshot.empty) {
      console.log('No organizations found in the database.');
      return;
    }
    
    console.log(`Found ${orgsSnapshot.docs.length} organization(s):\n`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      console.log(`🏢 Organization ID: ${orgDoc.id}`);
      console.log(`   Name: ${orgData.name || orgData.organizationName || 'Unnamed'}`);
      console.log(`   Created: ${orgData.createdAt?.toDate?.() || 'Unknown'}`);
      
      // Check locations
      const locationsSnapshot = await db
        .collection('organizations')
        .doc(orgDoc.id)
        .collection('locations')
        .get();
      
      console.log(`   Locations: ${locationsSnapshot.docs.length}`);
      
      // Check checklist templates
      const templatesSnapshot = await db
        .collection('organizations')
        .doc(orgDoc.id)
        .collection('checklist_templates')
        .get();
      
      console.log(`   Checklist templates: ${templatesSnapshot.docs.length}`);
      
      // Check for problematic templates
      let problematicCount = 0;
      for (const templateDoc of templatesSnapshot.docs) {
        const templateData = templateDoc.data();
        if (templateData.migratedToLocationSpecific === true || templateData.archived === true) {
          continue;
        }
        const locationIds = templateData.locationIds || [];
        const isProblematic = !Array.isArray(locationIds) || 
                             locationIds.length === 0 || 
                             locationIds.length > 1;
        if (isProblematic) problematicCount++;
      }
      
      console.log(`   Problematic checklists: ${problematicCount}`);
      console.log('   ─────────────────────────────────────\n');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

findAllOrganizations().then(() => process.exit(0));
