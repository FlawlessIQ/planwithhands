/**
 * Deep analysis of what data is captured vs what should be captured for daily summaries
 */

const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

function formatDate(date) {
  return date.getFullYear() + '-' +
    String(date.getMonth() + 1).padStart(2, '0') + '-' +
    String(date.getDate()).padStart(2, '0');
}

async function deepAnalyze() {
  console.log('🔍 DEEP ANALYSIS OF DAILY SUMMARY DATA CAPTURE\n');
  console.log('='.repeat(70));

  // Analyze Oct 7, 2025 (data that we know exists)
  const targetDate = new Date('2025-10-08T12:00:00'); // Use noon to avoid timezone issues
  const dateStr = formatDate(targetDate);
  console.log(`📅 Target Date: ${dateStr}\n`);

  // Analyze first organization with data
  const orgId = '3qjYzHagWmfbnMieJ1aj'; // Conors pub Group
  console.log(`🏢 Organization: Conors pub Group`);
  console.log('='.repeat(70));

  const stats = {
    totalChecklists: 0,
    totalTasks: 0,
    completedTasks: 0,
    incompleteTasks: 0,
    incompleteWithReason: 0,
    incompleteWithoutReason: 0,
    tasksWithNotes: 0,
    photoRequiredTasks: 0,
    photoProvidedTasks: 0,
    photoBypassedTasks: 0,
    sampleIncomplete: [],
    sampleNotes: [],
    samplePhotoBypassed: []
  };

  try {
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .get();

    for (const locDoc of locationsSnapshot.docs) {
      const locationId = locDoc.id;
      const locationData = locDoc.data();
      const locationName = locationData.locationName || 'Unknown';

      const checklistsSnapshot = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .get();

      console.log(`\n📍 Location: ${locationName} - ${checklistsSnapshot.docs.length} checklist(s)`);

      for (const checklistDoc of checklistsSnapshot.docs) {
        stats.totalChecklists++;
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'Unknown';

        const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
        console.log(`   📋 ${templateName} - ${tasksSnapshot.docs.length} tasks`);

        for (const taskDoc of tasksSnapshot.docs) {
          const task = taskDoc.data();
          stats.totalTasks++;

          const taskName = task.taskName || 'Unknown';
          const isCompleted = task.completed || task.isCompleted || false;
          const photoRequired = task.photoRequired || task.isCarryForwardEligible || false;
          const hasPhoto = !!(task.proofImageUrl || task.photoUrl);
          const hasNotes = !!(task.notes && task.notes.trim());
          const reason = task.reason || task.notCompletedReason || '';
          const hasReason = !!(reason && reason.trim());

          // Analyze completion status
          if (isCompleted) {
            stats.completedTasks++;

            // Check photo compliance for completed tasks
            if (photoRequired) {
              stats.photoRequiredTasks++;
              if (hasPhoto) {
                stats.photoProvidedTasks++;
              } else {
                stats.photoBypassedTasks++;
                if (stats.samplePhotoBypassed.length < 5) {
                  stats.samplePhotoBypassed.push({
                    task: taskName,
                    checklist: templateName,
                    location: locationName,
                    completedBy: task.completedByUserId || 'Unknown',
                    completedAt: task.completedAt ? task.completedAt.toDate() : null
                  });
                }
              }
            }

            // Check for notes on completed tasks
            if (hasNotes) {
              stats.tasksWithNotes++;
              if (stats.sampleNotes.length < 5) {
                stats.sampleNotes.push({
                  task: taskName,
                  checklist: templateName,
                  location: locationName,
                  notes: task.notes,
                  completedBy: task.completedByUserId || 'Unknown'
                });
              }
            }
          } else {
            // Incomplete task
            stats.incompleteTasks++;

            if (hasReason) {
              stats.incompleteWithReason++;
            } else {
              stats.incompleteWithoutReason++;
            }

            if (stats.sampleIncomplete.length < 10) {
              stats.sampleIncomplete.push({
                task: taskName,
                checklist: templateName,
                location: locationName,
                hasReason,
                reason: hasReason ? reason : null,
                photoRequired,
                hasNotes,
                notes: hasNotes ? task.notes : null
              });
            }
          }
        }

        // Check legacy array
        const legacyTasks = checklistData.tasks || [];
        if (legacyTasks.length > 0) {
          console.log(`   ⚠️  WARNING: ${legacyTasks.length} tasks in LEGACY array!`);
        }
      }
    }

    // Print comprehensive analysis
    console.log('\n\n' + '='.repeat(70));
    console.log('📊 COMPREHENSIVE ANALYSIS RESULTS');
    console.log('='.repeat(70));

    const completionRate = stats.totalTasks > 0 
      ? ((stats.completedTasks / stats.totalTasks) * 100).toFixed(1)
      : 0;
    const photoComplianceRate = stats.photoRequiredTasks > 0
      ? ((stats.photoProvidedTasks / stats.photoRequiredTasks) * 100).toFixed(1)
      : 100;

    console.log(`\n📈 OVERALL METRICS:`);
    console.log(`   Total Checklists:           ${stats.totalChecklists}`);
    console.log(`   Total Tasks:                ${stats.totalTasks}`);
    console.log(`   Completion Rate:            ${completionRate}% (${stats.completedTasks}/${stats.totalTasks})`);
    console.log(``);
    console.log(`❌ INCOMPLETE TASKS:            ${stats.incompleteTasks}`);
    console.log(`   With Reason:                ${stats.incompleteWithReason} (${stats.incompleteTasks > 0 ? ((stats.incompleteWithReason / stats.incompleteTasks) * 100).toFixed(1) : 0}%)`);
    console.log(`   Without Reason:             ${stats.incompleteWithoutReason} (${stats.incompleteTasks > 0 ? ((stats.incompleteWithoutReason / stats.incompleteTasks) * 100).toFixed(1) : 0}%)`);
    console.log(``);
    console.log(`📝 STAFF NOTES:                 ${stats.tasksWithNotes} tasks have notes`);
    console.log(``);
    console.log(`📷 PHOTO COMPLIANCE:`);
    console.log(`   Photo Required:             ${stats.photoRequiredTasks} tasks`);
    console.log(`   Photo Provided:             ${stats.photoProvidedTasks}`);
    console.log(`   Photo Bypassed:             ${stats.photoBypassedTasks} ⚠️`);
    console.log(`   Compliance Rate:            ${photoComplianceRate}%`);

    // Show samples
    if (stats.sampleIncomplete.length > 0) {
      console.log(`\n\n${'='.repeat(70)}`);
      console.log(`❌ SAMPLE INCOMPLETE TASKS (${stats.sampleIncomplete.length} shown, ${stats.incompleteTasks} total):`);
      console.log('='.repeat(70));
      stats.sampleIncomplete.forEach((item, i) => {
        console.log(`\n${i + 1}. "${item.task}"`);
        console.log(`   📍 ${item.location} > ${item.checklist}`);
        console.log(`   Has Reason: ${item.hasReason ? '✓ YES' : '✗ NO'}`);
        if (item.hasReason) {
          console.log(`   Reason: "${item.reason}"`);
        }
        if (item.photoRequired) {
          console.log(`   Photo Required: ✓ YES`);
        }
        if (item.hasNotes) {
          console.log(`   Notes: "${item.notes}"`);
        }
      });
    }

    if (stats.samplePhotoBypassed.length > 0) {
      console.log(`\n\n${'='.repeat(70)}`);
      console.log(`📷 SAMPLE PHOTO BYPASSED (${stats.samplePhotoBypassed.length} shown, ${stats.photoBypassedTasks} total):`);
      console.log('='.repeat(70));
      stats.samplePhotoBypassed.forEach((item, i) => {
        console.log(`\n${i + 1}. "${item.task}"`);
        console.log(`   📍 ${item.location} > ${item.checklist}`);
        console.log(`   Completed By: ${item.completedBy}`);
        console.log(`   Completed At: ${item.completedAt ? item.completedAt.toLocaleString() : 'Unknown'}`);
      });
    }

    if (stats.sampleNotes.length > 0) {
      console.log(`\n\n${'='.repeat(70)}`);
      console.log(`📝 SAMPLE STAFF NOTES (${stats.sampleNotes.length} shown, ${stats.tasksWithNotes} total):`);
      console.log('='.repeat(70));
      stats.sampleNotes.forEach((item, i) => {
        console.log(`\n${i + 1}. "${item.task}"`);
        console.log(`   📍 ${item.location} > ${item.checklist}`);
        console.log(`   Completed By: ${item.completedBy}`);
        console.log(`   Notes: "${item.notes}"`);
      });
    }

    console.log(`\n\n${'='.repeat(70)}`);
    console.log('✅ Analysis Complete!');
    console.log('='.repeat(70));

  } catch (error) {
    console.error('Error during analysis:', error);
  }

  process.exit(0);
}

deepAnalyze().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
