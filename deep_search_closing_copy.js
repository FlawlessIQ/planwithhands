const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function deepSearchClosingCopy() {
  try {
    console.log('=== Deep Search for CLOSING (Copy) ===\n');
    
    // Get ALL checklists from Chickies without date filter
    const allChecklists = await db
      .collection('organizations')
      .doc('FErQ4pkcrCovJ7T6L13M')
      .collection('locations')
      .doc('abTp8sjidL5QVirAewe6')
      .collection('daily_checklists')
      .get();
    
    console.log(`Scanning ${allChecklists.size} total checklists in Chickies...\n`);
    
    let foundCopy = [];
    let closingCount = 0;
    
    allChecklists.docs.forEach(doc => {
      const data = doc.data();
      
      // Check templateName
      if (data.templateName && data.templateName.toLowerCase().includes('closing')) {
        closingCount++;
        if (data.templateName.toLowerCase().includes('copy')) {
          foundCopy.push({
            id: doc.id,
            templateName: data.templateName,
            shiftId: data.shiftId,
            date: data.date,
            source: 'templateName'
          });
        }
      }
      
      // Check tasks array for checklistName
      if (data.tasks && Array.isArray(data.tasks)) {
        data.tasks.forEach(task => {
          if (task.checklistName && task.checklistName.toLowerCase().includes('closing') && task.checklistName.toLowerCase().includes('copy')) {
            // Check if we already added this checklist
            if (!foundCopy.find(c => c.id === doc.id)) {
              foundCopy.push({
                id: doc.id,
                templateName: data.templateName,
                taskChecklistName: task.checklistName,
                shiftId: data.shiftId,
                date: data.date,
                source: 'task.checklistName'
              });
            }
          }
        });
      }
    });
    
    console.log(`Found ${closingCount} checklists with "CLOSING" in name`);
    console.log(`Found ${foundCopy.length} checklists with "CLOSING (Copy)"\n`);
    
    if (foundCopy.length > 0) {
      console.log('🔴 FOUND CLOSING (Copy) CHECKLISTS:\n');
      foundCopy.forEach((item, index) => {
        console.log(`${index + 1}. Document ID: ${item.id}`);
        console.log(`   Template Name: ${item.templateName}`);
        if (item.taskChecklistName) {
          console.log(`   Task Checklist Name: ${item.taskChecklistName}`);
        }
        console.log(`   Shift ID: ${item.shiftId}`);
        console.log(`   Date: ${item.date}`);
        console.log(`   Found in: ${item.source}`);
        console.log('');
      });
    } else {
      console.log('✅ No checklists with "CLOSING (Copy)" found in database');
      console.log('\nLet me check what the app might be querying...');
      console.log('Checking if there\'s a "missed tasks" or summary collection...\n');
    }

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

deepSearchClosingCopy();
