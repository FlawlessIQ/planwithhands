/**
 * Deep analysis of daily summary data capture
 * Checks what data is being collected vs what should be collected
 */

const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Initialize Firebase Admin with the correct database
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

function formatDate(date) {
  return date.getFullYear() + '-' +
    String(date.getMonth() + 1).padStart(2, '0') + '-' +
    String(date.getDate()).padStart(2, '0');
}

async function analyzeDataCapture() {
  console.log('🔍 DEEP ANALYSIS OF DAILY SUMMARY DATA CAPTURE\n');
  console.log('='.repeat(60));

  // Use Oct 7, 2025 which has data
  const today = new Date('2025-10-07');
  const dateStr = formatDate(today);
  console.log(`📅 Analyzing date: ${dateStr}\n`);

  // Get first organization for detailed analysis
  const orgsSnapshot = await db.collection('organizations').limit(3).get();
  
  for (const orgDoc of orgsSnapshot.docs) {
    const orgId = orgDoc.id;
    const orgData = orgDoc.data();
    const orgName = orgData.organizationName || orgData.name || orgId;

    console.log(`\n🏢 Organization: ${orgName} (${orgId})`);
    console.log('='.repeat(60));

    // Collect data like the summary function does
    const analysis = {
      totalTasks: 0,
      completedTasks: 0,
      incompleteTasks: 0,
      tasksWithNotes: 0,
      tasksWithReasons: 0,
      tasksWithoutReasons: 0,
      photoRequired: 0,
      photoProvided: 0,
      photoBypassed: 0,
      details: []
    };

    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();

    console.log(`📍 Found ${locationsSnapshot.docs.length} location(s)`);

    for (const locationDoc of locationsSnapshot.docs) {
      const locationId = locationDoc.id;
      const locationData = locationDoc.data();
      const locationName = locationData.locationName || 'Unknown Location';

      // Get today's checklists
      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .get();

      console.log(`  📋 Location: ${locationName} - ${checklistsSnapshot.docs.length} checklist(s)`);

      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || checklistData.checklistName || 'Unknown';

        // Get tasks from subcollection
        const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
        
        console.log(`    ✓ Checklist: ${templateName} - ${tasksSnapshot.docs.length} tasks in subcollection`);

        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          analysis.totalTasks++;

          const taskName = taskData.taskName || 'Unknown Task';
          const isCompleted = taskData.completed || taskData.isCompleted || false;
          const photoRequired = taskData.photoRequired || taskData.isCarryForwardEligible || false;
          const hasPhoto = !!(taskData.proofImageUrl || taskData.photoUrl);
          const hasNotes = !!(taskData.notes && taskData.notes.trim());
          const reason = taskData.reason || taskData.notCompletedReason || '';
          const hasReason = !!(reason && reason.trim());

          if (isCompleted) {
            analysis.completedTasks++;
          } else {
            analysis.incompleteTasks++;
            
            if (hasReason) {
              analysis.tasksWithReasons++;
            } else {
              analysis.tasksWithoutReasons++;
            }
          }

          if (hasNotes) {
            analysis.tasksWithNotes++;
          }

          if (photoRequired) {
            analysis.photoRequired++;
            if (isCompleted) {
              if (hasPhoto) {
                analysis.photoProvided++;
              } else {
                analysis.photoBypassed++;
              }
            }
          }

          // Capture details of interesting tasks
          if (!isCompleted || (isCompleted && photoRequired && !hasPhoto) || hasNotes) {
            analysis.details.push({
              taskName,
              checklistName: templateName,
              locationName,
              isCompleted,
              hasNotes,
              notes: hasNotes ? taskData.notes : null,
              hasReason,
              reason: hasReason ? reason : null,
              photoRequired,
              hasPhoto,
              completedBy: taskData.completedByUserId || null,
              completedAt: taskData.completedAt || null
            });
          }
        }

        // Also check legacy tasks array (if exists)
        const legacyTasks = checklistData.tasks || [];
        if (legacyTasks.length > 0) {
          console.log(`    ⚠️  WARNING: Found ${legacyTasks.length} tasks in LEGACY array`);
        }
      }
    }

    // Calculate percentages
    const completionRate = analysis.totalTasks > 0 
      ? (analysis.completedTasks / analysis.totalTasks * 100).toFixed(1) 
      : 0;
    const photoComplianceRate = analysis.photoRequired > 0 
      ? (analysis.photoProvided / analysis.photoRequired * 100).toFixed(1) 
      : 100;

    console.log('\n📊 SUMMARY STATISTICS:');
    console.log('-'.repeat(60));
    console.log(`Total Tasks:              ${analysis.totalTasks}`);
    console.log(`Completed:                ${analysis.completedTasks} (${completionRate}%)`);
    console.log(`Incomplete:               ${analysis.incompleteTasks}`);
    console.log(`  ├─ With reason:         ${analysis.tasksWithReasons}`);
    console.log(`  └─ Without reason:      ${analysis.tasksWithoutReasons}`);
    console.log(`Tasks with notes:         ${analysis.tasksWithNotes}`);
    console.log(`Photo required:           ${analysis.photoRequired}`);
    console.log(`  ├─ Photo provided:      ${analysis.photoProvided}`);
    console.log(`  └─ Photo bypassed:      ${analysis.photoBypassed} ⚠️`);
    console.log(`Photo compliance:         ${photoComplianceRate}%`);

    // Show sample details
    if (analysis.details.length > 0) {
      console.log('\n🔍 DETAILED EXAMPLES:');
      console.log('-'.repeat(60));
      
      // Show incomplete tasks
      const incomplete = analysis.details.filter(d => !d.isCompleted);
      if (incomplete.length > 0) {
        console.log('\n❌ Incomplete Tasks:');
        incomplete.slice(0, 5).forEach((d, i) => {
          console.log(`  ${i + 1}. "${d.taskName}"`);
          console.log(`     Location: ${d.locationName}`);
          console.log(`     Checklist: ${d.checklistName}`);
          console.log(`     Has Reason: ${d.hasReason ? 'YES' : 'NO'}`);
          if (d.hasReason) {
            console.log(`     Reason: "${d.reason}"`);
          }
        });
        if (incomplete.length > 5) {
          console.log(`     ... and ${incomplete.length - 5} more incomplete tasks`);
        }
      }

      // Show photo bypassed
      const photoBypassed = analysis.details.filter(d => d.isCompleted && d.photoRequired && !d.hasPhoto);
      if (photoBypassed.length > 0) {
        console.log('\n📷 Photo Requirements Bypassed:');
        photoBypassed.slice(0, 3).forEach((d, i) => {
          console.log(`  ${i + 1}. "${d.taskName}"`);
          console.log(`     Location: ${d.locationName}`);
          console.log(`     Completed by: ${d.completedBy || 'Unknown'}`);
        });
        if (photoBypassed.length > 3) {
          console.log(`     ... and ${photoBypassed.length - 3} more`);
        }
      }

      // Show tasks with notes
      const withNotes = analysis.details.filter(d => d.hasNotes);
      if (withNotes.length > 0) {
        console.log('\n📝 Tasks with Staff Notes:');
        withNotes.slice(0, 3).forEach((d, i) => {
          console.log(`  ${i + 1}. "${d.taskName}"`);
          console.log(`     Notes: "${d.notes}"`);
          console.log(`     Completed by: ${d.completedBy || 'Unknown'}`);
        });
        if (withNotes.length > 3) {
          console.log(`     ... and ${withNotes.length - 3} more with notes`);
        }
      }
    }

    console.log('\n' + '='.repeat(60));
  }

  console.log('\n✅ Analysis complete!\n');
  process.exit(0);
}

analyzeDataCapture().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
