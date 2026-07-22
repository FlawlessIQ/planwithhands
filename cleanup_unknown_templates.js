#!/usr/bin/env node

/**
 * Cleanup script to remove "Unknown Template" checklists created by the Cloud Function
 * before we added template validation.
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function cleanupUnknownTemplateChecklists() {
  console.log('🧹 Starting cleanup of Unknown Template checklists...');
  
  const orgId = '5dQCGM4MTiJsqVoedI04'; // Hands organization
  let totalFound = 0;
  let totalCleaned = 0;
  
  try {
    // Get all locations
    const locationsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();
    
    console.log(`📍 Found ${locationsSnap.docs.length} locations to check`);
    
    for (const locationDoc of locationsSnap.docs) {
      const locationId = locationDoc.id;
      const locationName = locationDoc.data().locationName || locationId;
      
      console.log(`\n📋 Checking location: ${locationName}`);
      
      // Get all daily checklists for this location
      const checklistsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .get();
      
      for (const checklistDoc of checklistsSnap.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || '';
        const templateIds = checklistData.checklistTemplateIds || [];
        
        // Check if this checklist has problematic characteristics
        let isProblematic = false;
        let reason = '';
        
        // Case 1: Has "Unknown Template" name
        if (templateName.toLowerCase().includes('unknown template')) {
          isProblematic = true;
          reason = `templateName: "${templateName}"`;
        }
        
        // Case 2: Has invalid template IDs
        if (templateIds.length > 0) {
          const invalidTemplateIds = [];
          for (const templateId of templateIds) {
            try {
              const templateDoc = await db
                .collection('organizations')
                .doc(orgId)
                .collection('checklist_templates')
                .doc(templateId)
                .get();
              
              if (!templateDoc.exists) {
                invalidTemplateIds.push(templateId);
              } else {
                const templateData = templateDoc.data();
                const name = (templateData.name || '').toString().trim();
                if (!name || name.toLowerCase() === 'unknown template') {
                  invalidTemplateIds.push(templateId);
                }
              }
            } catch (err) {
              invalidTemplateIds.push(templateId);
            }
          }
          
          if (invalidTemplateIds.length > 0) {
            isProblematic = true;
            reason = `invalid template IDs: [${invalidTemplateIds.join(', ')}]`;
          }
        }
        
        if (isProblematic) {
          totalFound++;
          console.log(`  ❌ Found problematic checklist: ${checklistDoc.id}`);
          console.log(`     Date: ${checklistData.date}`);
          console.log(`     Shift: ${checklistData.shiftId}`);
          console.log(`     Reason: ${reason}`);
          
          // Ask for confirmation before deleting (in interactive mode)
          const shouldDelete = process.env.AUTO_DELETE || false;
          
          if (shouldDelete || process.argv.includes('--delete')) {
            try {
              // Delete tasks subcollection first
              const tasksSnap = await checklistDoc.ref.collection('tasks').get();
              const batch = db.batch();
              tasksSnap.docs.forEach(taskDoc => {
                batch.delete(taskDoc.ref);
              });
              
              // Delete the checklist itself
              batch.delete(checklistDoc.ref);
              
              await batch.commit();
              totalCleaned++;
              console.log(`     ✅ Deleted checklist and ${tasksSnap.docs.length} tasks`);
            } catch (err) {
              console.log(`     ❌ Error deleting: ${err.message}`);
            }
          } else {
            console.log(`     ⏸️  Skipped deletion (use --delete flag to actually delete)`);
          }
        }
      }
    }
    
    console.log(`\n📊 Cleanup Summary:`);
    console.log(`   Found problematic checklists: ${totalFound}`);
    console.log(`   Cleaned up: ${totalCleaned}`);
    
    if (totalFound > 0 && totalCleaned === 0) {
      console.log(`\n💡 To actually delete the problematic checklists, run:`);
      console.log(`   node cleanup_unknown_templates.js --delete`);
    }
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
}

// Run the cleanup
cleanupUnknownTemplateChecklists().then(() => {
  console.log('🏁 Cleanup complete');
  process.exit(0);
});