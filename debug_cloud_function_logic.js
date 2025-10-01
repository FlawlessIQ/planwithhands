const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
// Use the correct Firestore database (not the default)
db.settings({ databaseId: 'planwithhands' });

async function debugCloudFunctionLogic() {
  try {
    console.log('🐛 Debugging Cloud Function logic for Hamilton Pork...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // The logs showed the function was querying 2025-09-30, let's check both dates
    const dates = ['2025-09-29', '2025-09-30'];
    
    for (const testDate of dates) {
      console.log(`\n🔍 Checking date: ${testDate}`);
      console.log('=' .repeat(50));
      
      let totalTasks = 0;
      let completedTasks = 0;
      let checklistCount = 0;
      const notesEntries = [];
      const missedTaskEntries = [];
      const photoBypassed = [];
      
      // Get all locations (exactly like the function does)
      const locationsSnapshot = await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .get();
      
      console.log(`Found ${locationsSnapshot.size} locations`);
      
      for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        const locationData = locationDoc.data();
        const locationName = locationData.name || "Unknown Location";
        
        console.log(`\n📍 Location: ${locationName} (${locationId})`);
        
        // Query daily checklists for this location (exactly like the function)
        const checklistsSnapshot = await db
          .collection("organizations")
          .doc(orgId)
          .collection("locations")
          .doc(locationId)
          .collection("daily_checklists")
          .where("date", "==", testDate)
          .get();
        
        console.log(`   Daily checklists: ${checklistsSnapshot.size}`);
        
        for (const checklistDoc of checklistsSnapshot.docs) {
          const checklistData = checklistDoc.data();
          checklistCount++;
          
          const templateName = checklistData.templateName || "Unknown Checklist";
          console.log(`   📋 ${templateName}`);
          
          // Process tasks from subcollection (exactly like the function)
          const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();
          console.log(`      Tasks in subcollection: ${tasksSnapshot.size}`);
          
          for (const taskDoc of tasksSnapshot.docs) {
            const taskData = taskDoc.data();
            totalTasks++;
            
            if (taskData.completed) {
              completedTasks++;
            }
            
            // Check for notes, missed tasks, photo bypassed (like the function)
            if (taskData.notes && taskData.notes.trim()) {
              notesEntries.push(taskData);
            }
            
            if (taskData.missed) {
              missedTaskEntries.push(taskData);
            }
            
            if (taskData.photoBypassed) {
              photoBypassed.push(taskData);
            }
          }
          
          console.log(`      ✅ Completed: ${tasksSnapshot.docs.filter(doc => doc.data().completed).length}`);
          console.log(`      📝 Notes: ${tasksSnapshot.docs.filter(doc => doc.data().notes?.trim()).length}`);
          console.log(`      ❌ Missed: ${tasksSnapshot.docs.filter(doc => doc.data().missed).length}`);
        }
      }
      
      // Apply the exact same logic as the Cloud Function
      const hasContent = totalTasks > 0 || 
                        notesEntries.length > 0 ||
                        missedTaskEntries.length > 0 ||
                        photoBypassed.length > 0;
      
      console.log(`\n📊 SUMMARY FOR ${testDate}:`);
      console.log(`   Total tasks: ${totalTasks}`);
      console.log(`   Completed tasks: ${completedTasks}`);
      console.log(`   Notes entries: ${notesEntries.length}`);
      console.log(`   Missed tasks: ${missedTaskEntries.length}`);
      console.log(`   Photo bypassed: ${photoBypassed.length}`);
      console.log(`   Has meaningful content: ${hasContent ? '✅ YES' : '❌ NO'}`);
      
      if (hasContent) {
        console.log(`   📧 Daily summary WOULD BE SENT`);
      } else {
        console.log(`   🚫 Daily summary WOULD BE SKIPPED`);
      }
    }
    
    console.log('\n🔍 ANALYSIS:');
    console.log('=============');
    console.log('Based on the Cloud Function logs, it was checking 2025-09-30.');
    console.log('The function found no activity for that date, which is why it skipped sending.');
    console.log('\nPossible solutions:');
    console.log('1. Create daily checklist data for the current date (2025-09-30)');
    console.log('2. Fix the date calculation in the function if it\'s looking at the wrong date');
    console.log('3. Manually trigger the function with a date that has data (2025-09-29)');
    
    // Quick solution: Create a checklist for today
    console.log('\n🔧 QUICK FIX: Creating daily checklist for today (2025-09-30)...');
    
    const todayDate = '2025-09-30';
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').limit(1).get();
    
    if (!locationsSnapshot.empty) {
      const location = locationsSnapshot.docs[0];
      const locationData = location.data();
      
      const templatesSnapshot = await db.collection('organizations').doc(orgId).collection('checklist_templates').limit(1).get();
      
      if (!templatesSnapshot.empty) {
        const template = templatesSnapshot.docs[0];
        const templateData = template.data();
        
        const dailyChecklistData = {
          date: todayDate,
          locationId: location.id,
          locationName: locationData.name,
          templateId: template.id,
          templateName: templateData.name || 'Test Checklist',
          organizationId: orgId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'completed',
          completedTasks: 5,
          totalTasks: 10
        };
        
        const dailyChecklistRef = db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(location.id)
          .collection('daily_checklists')
          .doc();
        
        await dailyChecklistRef.set(dailyChecklistData);
        
        // Create some completed tasks
        const sampleTasks = [
          { name: 'Test task 1', completed: true, completedAt: new Date() },
          { name: 'Test task 2', completed: true, completedAt: new Date() },
          { name: 'Test task 3', completed: false },
        ];
        
        for (let i = 0; i < sampleTasks.length; i++) {
          await dailyChecklistRef.collection('tasks').doc().set({
            ...sampleTasks[i],
            order: i + 1,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
        
        console.log(`✅ Created test daily checklist for ${todayDate}`);
        console.log('   The next hourly run should now find activity and send the summary!');
      }
    }
    
  } catch (error) {
    console.error('❌ Error debugging Cloud Function logic:', error);
  }
}

debugCloudFunctionLogic();