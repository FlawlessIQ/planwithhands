const { getDB, admin } = require('./firebase_config');

const db = getDB();

async function fixMisplacedDailyChecklists() {
  console.log('🛠️ Fixing misplaced daily checklists...');
  console.log('='.repeat(60));

  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const hamiltonLocationId = 'fW45ffBBPar5EaNodDYq'; // Hamilton Pork
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6'; // Chickies
    const innLocationId = '9uPGxodhJADOHTCS6Oqz'; // Inn

    const issues = [];
    
    // Check all three locations for misplaced checklists
    const locations = [
      { id: hamiltonLocationId, name: 'Hamilton Pork', expectedPrefix: 'P' },
      { id: chickiesLocationId, name: 'Chickies', expectedPrefix: 'C' },
      { id: innLocationId, name: 'The Hamilton Inn', expectedPrefix: 'I' }
    ];

    for (const location of locations) {
      console.log(`\n🔍 Checking ${location.name} (${location.id}) for misplaced checklists...`);
      
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(location.id)
        .collection('daily_checklists')
        .get();

      console.log(`   Found ${checklistsSnapshot.size} total checklists`);

      let correctCount = 0;
      let wrongCount = 0;

      for (const doc of checklistsSnapshot.docs) {
        const data = doc.data();
        const docId = doc.id;
        const checklistName = data.checklistName || data.templateName || data.name || 'NO NAME';
        const templateId = data.templateId || data.checklistTemplateId;
        
        // Determine expected prefix based on checklist name
        let actualPrefix = '';
        if (checklistName.startsWith('C ')) actualPrefix = 'C';
        else if (checklistName.startsWith('P ')) actualPrefix = 'P';
        else if (checklistName.startsWith('I ')) actualPrefix = 'I';

        if (actualPrefix && actualPrefix !== location.expectedPrefix) {
          wrongCount++;
          issues.push({
            docId,
            checklistName,
            templateId,
            currentLocation: location.name,
            currentLocationId: location.id,
            actualPrefix,
            expectedPrefix: location.expectedPrefix,
            data
          });
          
          console.log(`   ❌ WRONG: "${checklistName}" (${actualPrefix} in ${location.expectedPrefix} location)`);
        } else if (actualPrefix === location.expectedPrefix) {
          correctCount++;
        }
      }

      console.log(`   ✅ Correct: ${correctCount}, ❌ Wrong: ${wrongCount}`);
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 SUMMARY OF ISSUES:');
    console.log(`   Total misplaced checklists found: ${issues.length}`);

    if (issues.length === 0) {
      console.log('✅ No misplaced checklists found!');
      return;
    }

    // Group issues by location
    const issuesByLocation = {};
    issues.forEach(issue => {
      if (!issuesByLocation[issue.currentLocation]) {
        issuesByLocation[issue.currentLocation] = [];
      }
      issuesByLocation[issue.currentLocation].push(issue);
    });

    Object.keys(issuesByLocation).forEach(locationName => {
      const locationIssues = issuesByLocation[locationName];
      console.log(`\n❌ ${locationName}: ${locationIssues.length} misplaced checklists`);
      locationIssues.forEach(issue => {
        console.log(`   - "${issue.checklistName}" (should be in ${issue.actualPrefix} location)`);
      });
    });

    // Offer to fix
    console.log('\n🛠️ FIXING MISPLACED CHECKLISTS:');
    console.log('   Deleting misplaced checklist instances...');
    
    let deletedCount = 0;
    const batch = db.batch();

    for (const issue of issues) {
      const docRef = db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(issue.currentLocationId)
        .collection('daily_checklists').doc(issue.docId);
      
      batch.delete(docRef);
      deletedCount++;
      console.log(`   🗑️ Deleting: "${issue.checklistName}" from ${issue.currentLocation}`);
    }

    if (deletedCount > 0) {
      await batch.commit();
      console.log(`\n✅ Successfully deleted ${deletedCount} misplaced checklists`);
      
      console.log('\n📋 RESULT:');
      console.log('   - Chickies templates no longer appear in Hamilton Pork');
      console.log('   - Hamilton Pork templates no longer appear in other locations');
      console.log('   - Inn templates no longer appear in other locations');
      console.log('   - Daily checklist generation will need to be re-run for today');
    }

    console.log('\n🔄 NEXT STEPS:');
    console.log('   1. The misplaced checklists have been removed');
    console.log('   2. Your app should regenerate the correct checklists automatically');
    console.log('   3. Only location-appropriate templates will be used going forward');

  } catch (error) {
    console.error('❌ Fix failed:', error);
  }
}

fixMisplacedDailyChecklists();