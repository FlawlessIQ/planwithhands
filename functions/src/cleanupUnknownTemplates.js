/**
 * Clean up Unknown Template checklists and identify problematic shift configurations
 * 
 * This script will:
 * 1. Find all "Unknown Template" checklists being generated
 * 2. Identify which templates in shift configurations are deleted/inactive/missing
 * 3. Clean up existing unknown template checklists
 * 4. Provide recommendations for fixing shift configurations
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function cleanupUnknownTemplates(orgId, dryRun = true) {
  console.log(`\n${'='.repeat(80)}`);
  console.log(`UNKNOWN TEMPLATE CLEANUP - ${dryRun ? 'DRY RUN' : 'LIVE RUN'}`);
  console.log(`Organization: ${orgId}`);
  console.log(`${'='.repeat(80)}\n`);

  const results = {
    shifts: [],
    problemTemplates: [],
    orphanedChecklists: [],
    recommendations: []
  };

  try {
    // Step 1: Get all shifts in the organization
    console.log('Step 1: Analyzing shifts and templates...\n');
    
    const shiftsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .get();

    console.log(`Found ${shiftsSnap.size} shifts\n`);

    for (const shiftDoc of shiftsSnap.docs) {
      const shiftData = shiftDoc.data();
      const shiftId = shiftDoc.id;
      const shiftName = shiftData.shiftName || shiftId;
      const templateIds = shiftData.checklistTemplateIds || [];

      console.log(`Shift: ${shiftName} (${shiftId})`);
      console.log(`  Template IDs: ${templateIds.length}`);

      const shiftResult = {
        id: shiftId,
        name: shiftName,
        totalTemplates: templateIds.length,
        validTemplates: [],
        problemTemplates: []
      };

      // Check each template
      for (const templateId of templateIds) {
        try {
          const templateDoc = await db
            .collection('organizations')
            .doc(orgId)
            .collection('checklist_templates')
            .doc(templateId)
            .get();

          if (!templateDoc.exists) {
            console.log(`  ❌ ${templateId}: NOT FOUND (template deleted)`);
            shiftResult.problemTemplates.push({
              id: templateId,
              issue: 'Template does not exist',
              recommendation: 'Remove from shift configuration'
            });
            results.problemTemplates.push({
              templateId,
              shiftId,
              shiftName,
              issue: 'NOT_FOUND'
            });
          } else {
            const templateData = templateDoc.data();
            const name = templateData.name;
            const deleted = templateData.deleted === true;
            const active = templateData.active !== false;
            const hasName = name && name.trim().length > 0;

            let status = '✅';
            let issues = [];

            if (!hasName) {
              status = '❌';
              issues.push('NO NAME');
              shiftResult.problemTemplates.push({
                id: templateId,
                name: name || '(no name)',
                issue: 'Template has no name',
                recommendation: 'Add a name to the template or remove from shift'
              });
              results.problemTemplates.push({
                templateId,
                shiftId,
                shiftName,
                issue: 'NO_NAME'
              });
            }

            if (deleted) {
              status = '❌';
              issues.push('DELETED');
              shiftResult.problemTemplates.push({
                id: templateId,
                name: name || '(no name)',
                issue: 'Template is marked as deleted',
                recommendation: 'Remove from shift configuration'
              });
              results.problemTemplates.push({
                templateId,
                shiftId,
                shiftName,
                issue: 'DELETED'
              });
            }

            if (!active) {
              status = '⚠️';
              issues.push('INACTIVE');
              shiftResult.problemTemplates.push({
                id: templateId,
                name: name || '(no name)',
                issue: 'Template is inactive',
                recommendation: 'Activate template or remove from shift'
              });
              results.problemTemplates.push({
                templateId,
                shiftId,
                shiftName,
                issue: 'INACTIVE'
              });
            }

            if (issues.length === 0) {
              shiftResult.validTemplates.push({
                id: templateId,
                name: name
              });
              console.log(`  ${status} ${templateId}: ${name}`);
            } else {
              console.log(`  ${status} ${templateId}: ${name || '(no name)'} [${issues.join(', ')}]`);
            }
          }
        } catch (error) {
          console.error(`  Error checking template ${templateId}:`, error.message);
        }
      }

      results.shifts.push(shiftResult);
      console.log('');
    }

    // Step 2: Find orphaned "Unknown Template" checklists
    console.log('\nStep 2: Finding orphaned checklists with unknown templates...\n');

    const locationsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();

    let totalOrphaned = 0;

    for (const locationDoc of locationsSnap.docs) {
      const locationId = locationDoc.id;
      const locationName = locationDoc.data().name || locationId;

      const checklistsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .where('templateName', '==', null)
        .get();

      if (checklistsSnap.size > 0) {
        console.log(`Location: ${locationName} (${locationId})`);
        console.log(`  Found ${checklistsSnap.size} checklists with missing template names`);
        totalOrphaned += checklistsSnap.size;

        for (const checklistDoc of checklistsSnap.docs) {
          const checklistData = checklistDoc.data();
          results.orphanedChecklists.push({
            locationId,
            locationName,
            checklistId: checklistDoc.id,
            date: checklistData.date,
            templateId: checklistData.checklistTemplateId,
            shiftId: checklistData.shiftId
          });

          if (!dryRun) {
            // Delete the checklist and its tasks subcollection
            console.log(`  Deleting checklist ${checklistDoc.id}...`);
            
            // Delete tasks subcollection
            const tasksSnap = await checklistDoc.ref.collection('tasks').get();
            const batch = db.batch();
            tasksSnap.docs.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            
            // Delete checklist document
            await checklistDoc.ref.delete();
          }
        }
      }
    }

    console.log(`\nTotal orphaned checklists found: ${totalOrphaned}\n`);

    // Step 3: Generate recommendations
    console.log('Step 3: Generating recommendations...\n');

    if (results.problemTemplates.length > 0) {
      console.log('⚠️  ACTION REQUIRED: The following templates need attention:\n');

      // Group by shift
      const byShift = {};
      results.problemTemplates.forEach(pt => {
        if (!byShift[pt.shiftId]) {
          byShift[pt.shiftId] = {
            shiftName: pt.shiftName,
            templates: []
          };
        }
        byShift[pt.shiftId].templates.push(pt);
      });

      Object.entries(byShift).forEach(([shiftId, data]) => {
        console.log(`Shift: ${data.shiftName} (${shiftId})`);
        data.templates.forEach(pt => {
          console.log(`  - Template ${pt.templateId}: ${pt.issue}`);
        });
        console.log(`  Recommendation: Update shift configuration to remove these template IDs\n`);
      });

      results.recommendations.push({
        type: 'SHIFT_CLEANUP',
        message: 'Update shift configurations to remove deleted/invalid templates',
        shifts: Object.keys(byShift)
      });
    } else {
      console.log('✅ All templates in shift configurations are valid!\n');
    }

    // Summary
    console.log(`\n${'='.repeat(80)}`);
    console.log('SUMMARY');
    console.log(`${'='.repeat(80)}\n`);
    console.log(`Total shifts analyzed: ${results.shifts.length}`);
    console.log(`Problem templates found: ${results.problemTemplates.length}`);
    console.log(`Orphaned checklists found: ${totalOrphaned}`);
    
    if (dryRun) {
      console.log(`\n⚠️  This was a DRY RUN - no changes were made`);
      console.log(`To execute cleanup, run with dryRun=false\n`);
    } else {
      console.log(`\n✅ Cleanup completed - ${totalOrphaned} checklists deleted\n`);
    }

    return results;

  } catch (error) {
    console.error('Error during cleanup:', error);
    throw error;
  }
}

// Export for use in Cloud Functions
module.exports = { cleanupUnknownTemplates };

// If run directly
if (require.main === module) {
  const orgId = process.argv[2] || 'FErQ4pkcrCovJ7T6L13M';
  const dryRun = process.argv[3] !== 'execute';

  cleanupUnknownTemplates(orgId, dryRun)
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}
