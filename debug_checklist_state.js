#!/usr/bin/env node

/**
 * Debug script to investigate the current state of checklists and templates
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function debugChecklistState() {
  console.log('🔍 Debugging checklist state...');
  
  const orgId = '5dQCGM4MTiJsqVoedI04'; // Hands organization
  
  try {
    // Check if org exists
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    
    console.log('✅ Organization found:', orgDoc.data().name || orgId);
    
    // Check locations
    const locationsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`📍 Found ${locationsSnap.docs.length} locations`);
    
    if (locationsSnap.docs.length === 0) {
      console.log('❌ No locations found - checking if they exist elsewhere...');
      
      // Check top-level locations
      const topLocationsSnap = await db.collection('locations').get();
      console.log(`📍 Found ${topLocationsSnap.docs.length} top-level locations`);
      
      // Check a few documents to see the structure
      for (const locationDoc of topLocationsSnap.docs.slice(0, 3)) {
        const data = locationDoc.data();
        console.log(`   Location: ${data.locationName || locationDoc.id}`);
        console.log(`   Org ID: ${data.organizationId || 'none'}`);
      }
      return;
    }
    
    // Check each location for checklists
    for (const locationDoc of locationsSnap.docs) {
      const locationId = locationDoc.id;
      const locationData = locationDoc.data();
      const locationName = locationData.locationName || locationId;
      
      console.log(`\n📋 Checking location: ${locationName}`);
      
      // Get today's date
      const today = new Date();
      const dateString = today.toISOString().split('T')[0]; // YYYY-MM-DD
      
      // Check recent checklists
      const checklistsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .orderBy('date', 'desc')
        .limit(5)
        .get();
      
      console.log(`   Found ${checklistsSnap.docs.length} recent checklists`);
      
      for (const checklistDoc of checklistsSnap.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'No template name';
        const templateIds = checklistData.checklistTemplateIds || [];
        
        console.log(`     📋 ${checklistDoc.id}`);
        console.log(`        Date: ${checklistData.date}`);
        console.log(`        Template Name: ${templateName}`);
        console.log(`        Template IDs: [${templateIds.join(', ')}]`);
        console.log(`        Shift: ${checklistData.shiftId}`);
        
        // Check if template name suggests Unknown Template issue
        if (templateName.toLowerCase().includes('unknown')) {
          console.log(`        ❌ POTENTIAL PROBLEM: Contains "unknown"`);
        }
        
        // Check template validity
        for (const templateId of templateIds) {
          try {
            const templateDoc = await db
              .collection('organizations')
              .doc(orgId)
              .collection('checklist_templates')
              .doc(templateId)
              .get();
            
            if (templateDoc.exists) {
              const templateData = templateDoc.data();
              const name = templateData.name || 'No name';
              console.log(`        ✅ Template ${templateId}: "${name}"`);
            } else {
              console.log(`        ❌ Template ${templateId}: NOT FOUND`);
            }
          } catch (err) {
            console.log(`        ❌ Template ${templateId}: ERROR - ${err.message}`);
          }
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error during debug:', error);
  }
}

// Run the debug
debugChecklistState().then(() => {
  console.log('🏁 Debug complete');
  process.exit(0);
});