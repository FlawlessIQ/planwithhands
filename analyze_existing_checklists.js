const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function analyzeExistingChecklists() {
  try {
    console.log('🔍 Analyzing the existing checklists to understand their structure...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
    const preDinnerShiftId = 'JLo4mc11PpjK9HOdRcdV';
    const date = '2025-09-29';
    
    // Get the Pre Dinner checklists
    const preDinnerQuery = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .where('shiftId', '==', preDinnerShiftId);
    
    const preDinnerSnapshot = await preDinnerQuery.get();
    
    console.log(`Found ${preDinnerSnapshot.size} Pre Dinner checklists for today:\n`);
    
    for (const doc of preDinnerSnapshot.docs) {
      const data = doc.data();
      console.log(`📋 CHECKLIST: ${data.templateName}`);
      console.log(`   Document ID: ${doc.id}`);
      console.log(`   Template ID: ${data.templateId || 'MISSING'}`);
      console.log(`   Job Types: ${JSON.stringify(data.jobTypes || [])}`);
      console.log(`   Created: ${data.createdAt || 'MISSING'}`);
      
      // Check if this checklist has tasks
      const tasksSnapshot = await db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(chickiesLocationId)
        .collection('daily_checklists')
        .doc(doc.id)
        .collection('tasks')
        .limit(5)
        .get();
      
      console.log(`   Tasks: ${tasksSnapshot.size} found`);
      
      if (!tasksSnapshot.empty) {
        console.log(`   Sample tasks:`);
        tasksSnapshot.forEach((taskDoc, index) => {
          const taskData = taskDoc.data();
          console.log(`     ${index + 1}. ${taskData.title || taskData.name || 'Unnamed task'}`);
        });
      }
      
      console.log('');
    }
    
    // Now let's test the actual fix - refresh the app to see if the templateId fix worked
    console.log('🎯 SUMMARY:');
    console.log(`- Found ${preDinnerSnapshot.size} Pre Dinner checklists`);
    console.log(`- All should now have proper templateId fields (fixed earlier)`);
    console.log(`- The 2 missing checklists (C Bar and C Server Pre Dinner) don't exist`);
    console.log(`- This suggests they were never properly created or were deleted during migration`);
    
    console.log('\n💡 NEXT STEPS:');
    console.log('1. First test: Refresh the Flutter app to see if the templateId fix worked');
    console.log('2. If the 2 existing checklists now show properly, we know the fix worked');
    console.log('3. Then we can investigate why the other 2 checklists are missing');
    console.log('4. We may need to recreate them or check if they have different names');
    
    console.log('\n🔄 Try refreshing the app now and let me know what you see!');
    
  } catch (error) {
    console.error('Error analyzing checklists:', error);
  }
}

analyzeExistingChecklists();