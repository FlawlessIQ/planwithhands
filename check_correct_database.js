#!/usr/bin/env node

/**
 * Check if we can connect to the correct Firestore database and find the organization
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with explicit database ID
if (!admin.apps.length) {
  admin.initializeApp();
}

// Connect to the planwithhands database specifically
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkCorrectDatabase() {
  console.log('🔍 Checking planwithhands database...');
  
  const targetOrgId = '5dQCGM4MTiJsqVoedI04';
  
  try {
    // Check if the target organization exists
    const orgDoc = await db.collection('organizations').doc(targetOrgId).get();
    
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log('✅ Found target organization!');
      console.log(`   Name: ${orgData.name || orgData.organizationName || 'No name'}`);
      
      // Check locations
      const locationsSnap = await db
        .collection('organizations')
        .doc(targetOrgId)
        .collection('locations')
        .get();
      
      console.log(`📍 Found ${locationsSnap.docs.length} locations`);
      
      for (const locDoc of locationsSnap.docs) {
        const locationId = locDoc.id;
        const locationData = locDoc.data();
        console.log(`   📍 Location: ${locationData.locationName || locationId}`);
        
        // Check for recent checklists
        const checklistsSnap = await db
          .collection('organizations')
          .doc(targetOrgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .orderBy('date', 'desc')
          .limit(5)
          .get();
        
        console.log(`     📋 Found ${checklistsSnap.docs.length} recent checklists`);
        
        for (const checklistDoc of checklistsSnap.docs) {
          const checklistData = checklistDoc.data();
          const templateName = checklistData.templateName || 'No template name';
          const templateIds = checklistData.checklistTemplateIds || [];
          
          console.log(`       📋 ${checklistDoc.id}`);
          console.log(`          Date: ${checklistData.date}`);
          console.log(`          Template Name: "${templateName}"`);
          console.log(`          Template IDs: [${templateIds.join(', ')}]`);
          console.log(`          Shift: ${checklistData.shiftId}`);
          
          // Check if this is the Unknown Template issue
          if (templateName.toLowerCase().includes('unknown')) {
            console.log(`          ❌ UNKNOWN TEMPLATE FOUND!`);
            
            // Check what templates these IDs point to
            for (const templateId of templateIds) {
              try {
                const templateDoc = await db
                  .collection('organizations')
                  .doc(targetOrgId)
                  .collection('checklist_templates')
                  .doc(templateId)
                  .get();
                
                if (templateDoc.exists) {
                  const templateData = templateDoc.data();
                  console.log(`            Template ${templateId}: "${templateData.name || 'No name'}"`);
                } else {
                  console.log(`            Template ${templateId}: ❌ NOT FOUND`);
                }
              } catch (err) {
                console.log(`            Template ${templateId}: ❌ ERROR - ${err.message}`);
              }
            }
          }
        }
      }
    } else {
      console.log('❌ Target organization not found in planwithhands database');
      
      // List what organizations do exist
      const orgsSnap = await db.collection('organizations').limit(5).get();
      console.log(`📊 Found ${orgsSnap.docs.length} organizations in this database:`);
      for (const orgDoc of orgsSnap.docs) {
        const orgData = orgDoc.data();
        console.log(`   🏢 ${orgDoc.id}: ${orgData.name || orgData.organizationName || 'No name'}`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error checking database:', error);
  }
}

// Run the check
checkCorrectDatabase().then(() => {
  console.log('🏁 Check complete');
  process.exit(0);
});