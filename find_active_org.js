#!/usr/bin/env node

/**
 * Find the active organization by looking for recent checklist activity
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function findActiveOrganization() {
  console.log('🔍 Finding active organization by recent activity...');
  
  try {
    // Get today's date
    const today = new Date();
    const dateString = today.toISOString().split('T')[0]; // YYYY-MM-DD
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayString = yesterday.toISOString().split('T')[0];
    
    console.log(`📅 Looking for activity on ${yesterdayString} and ${dateString}`);
    
    // List all organizations
    const orgsSnap = await db.collection('organizations').get();
    console.log(`📊 Checking ${orgsSnap.docs.length} organizations for activity...`);
    
    for (const orgDoc of orgsSnap.docs) {
      const orgId = orgDoc.id;
      let totalChecklists = 0;
      let recentChecklists = 0;
      
      // Check locations in this org
      const locationsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      if (locationsSnap.docs.length === 0) continue;
      
      for (const locDoc of locationsSnap.docs) {
        const locationId = locDoc.id;
        
        // Count total checklists
        const allChecklistsSnap = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .limit(10)
          .get();
        
        totalChecklists += allChecklistsSnap.docs.length;
        
        // Count recent checklists
        const recentChecklistsSnap = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', 'in', [yesterdayString, dateString])
          .get();
        
        recentChecklists += recentChecklistsSnap.docs.length;
        
        // If we found recent activity, show details
        if (recentChecklistsSnap.docs.length > 0) {
          console.log(`\n🏢 ACTIVE ORG: ${orgId}`);
          console.log(`   📍 Location: ${locDoc.data().locationName || locationId}`);
          console.log(`   📋 Total checklists: ${totalChecklists}`);
          console.log(`   📋 Recent checklists: ${recentChecklists}`);
          
          // Show recent checklist details
          for (const checklistDoc of recentChecklistsSnap.docs) {
            const checklistData = checklistDoc.data();
            const templateName = checklistData.templateName || 'No template name';
            const templateIds = checklistData.checklistTemplateIds || [];
            
            console.log(`     📋 ${checklistDoc.id}`);
            console.log(`        Date: ${checklistData.date}`);
            console.log(`        Template Name: "${templateName}"`);
            console.log(`        Template IDs: [${templateIds.join(', ')}]`);
            console.log(`        Shift: ${checklistData.shiftId}`);
            
            // Check if this looks like Unknown Template issue
            if (templateName.toLowerCase().includes('unknown')) {
              console.log(`        ❌ UNKNOWN TEMPLATE DETECTED!`);
            }
          }
        }
      }
      
      if (totalChecklists > 0) {
        console.log(`📊 Org ${orgId}: ${totalChecklists} total, ${recentChecklists} recent`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error finding active organization:', error);
  }
}

// Run the search
findActiveOrganization().then(() => {
  console.log('🏁 Search complete');
  process.exit(0);
});