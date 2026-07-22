#!/usr/bin/env node

/**
 * Find organizations with any checklist activity in the last week
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function findRecentActivity() {
  console.log('🔍 Finding organizations with activity in the last week...');
  
  try {
    // Get date range for last week
    const dates = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split('T')[0]);
    }
    
    console.log(`📅 Checking dates: ${dates.join(', ')}`);
    
    // Check organizations with highest activity
    const orgsToCheck = ['cf-org', 'cf-org-2', 'multi-org', 'test-org-id'];
    
    for (const orgId of orgsToCheck) {
      console.log(`\n🏢 Checking org: ${orgId}`);
      
      // Get locations
      const locationsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      console.log(`   📍 Found ${locationsSnap.docs.length} locations`);
      
      for (const locDoc of locationsSnap.docs) {
        const locationId = locDoc.id;
        const locationData = locDoc.data();
        console.log(`   📍 Location: ${locationData.locationName || locationId}`);
        
        // Get all checklists to see what dates they have
        const checklistsSnap = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .orderBy('date', 'desc')
          .limit(10)
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
          console.log(`          Created by: ${checklistData.createdBy || 'unknown'}`);
          
          // Check if this looks like Unknown Template issue
          if (templateName.toLowerCase().includes('unknown')) {
            console.log(`          ❌ UNKNOWN TEMPLATE DETECTED!`);
          }
          
          // This looks like the active organization
          if (checklistsSnap.docs.length > 0) {
            console.log(`   ⭐ This appears to be the ACTIVE organization!`);
          }
        }
      }
    }
    
  } catch (error) {
    console.error('❌ Error finding recent activity:', error);
  }
}

// Run the search
findRecentActivity().then(() => {
  console.log('🏁 Search complete');
  process.exit(0);
});