const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function analyzeUnknownShift() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = '9uPGxodhJADOHTCS6Oqz'; // The Hamilton Inn
    const unknownShiftId = 'AaWOWV83vEU7dRns0jpo';
    
    console.log('🔍 Analyzing unknown shift...\n');
    console.log(`Shift ID: ${unknownShiftId}\n`);
    console.log(`${'='.repeat(80)}\n`);
    
    // Check if shift exists at org level
    const shiftDoc = await db
      .collection('organizations').doc(orgId)
      .collection('shifts').doc(unknownShiftId)
      .get();
    
    console.log(`Shift exists at org level: ${shiftDoc.exists}\n`);
    
    if (!shiftDoc.exists) {
      console.log('❌ Shift document does not exist (likely deleted)\n');
    }
    
    console.log(`${'='.repeat(80)}\n`);
    
    // Find all checklists using this shift across all dates
    console.log('📋 Finding all checklists using this shift...\n');
    
    const dates = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date('2025-10-12');
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split('T')[0]);
    }
    
    const checklistsByDate = {};
    let totalChecklists = 0;
    
    for (const dateStr of dates) {
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', dateStr)
        .where('shiftId', '==', unknownShiftId)
        .get();
      
      if (checklistsSnapshot.docs.length > 0) {
        checklistsByDate[dateStr] = checklistsSnapshot.docs.map(doc => {
          const data = doc.data();
          return {
            id: doc.id,
            templateName: data.templateName,
            templateId: data.checklistTemplateId,
            totalItems: data.totalItems || 0,
            completedItems: data.completedItems || 0,
          };
        });
        totalChecklists += checklistsSnapshot.docs.length;
      }
    }
    
    console.log(`Found ${totalChecklists} checklists across ${Object.keys(checklistsByDate).length} dates:\n`);
    
    for (const [date, checklists] of Object.entries(checklistsByDate)) {
      console.log(`  ${date}:`);
      checklists.forEach(c => {
        console.log(`    - ${c.templateName} (${c.completedItems}/${c.totalItems} completed)`);
      });
      console.log('');
    }
    
    console.log(`${'='.repeat(80)}\n`);
    
    // Analyze the templates to figure out what shift this should be
    console.log('🔎 Analyzing checklist templates to determine shift type...\n');
    
    const templateNames = new Set();
    Object.values(checklistsByDate).flat().forEach(c => {
      templateNames.add(c.templateName);
    });
    
    console.log(`Unique template names:`);
    templateNames.forEach(name => {
      console.log(`  - ${name}`);
    });
    
    console.log('\n💡 Based on template names, this appears to be a BRUNCH/WEEKEND shift\n');
    console.log(`${'='.repeat(80)}\n`);
    
    // Look for similar shifts that exist
    console.log('🔍 Looking for similar existing shifts...\n');
    
    const allShiftsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('shifts')
      .get();
    
    console.log('Existing shifts:\n');
    allShiftsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const name = data.shiftName || data.name || 'Unnamed';
      const days = data.days || [];
      const repeatsDaily = data.repeatsDaily === true;
      
      if (name.toLowerCase().includes('brunch') || name.toLowerCase().includes('open')) {
        console.log(`  📅 ${name} (${doc.id})`);
        if (repeatsDaily) {
          console.log(`     Repeats daily: true`);
        } else {
          console.log(`     Days: ${days.join(', ')}`);
        }
        console.log(`     Templates: ${(data.checklistTemplateIds || []).length}`);
        console.log('');
      }
    });
    
    console.log(`${'='.repeat(80)}\n`);
    
    console.log('🛠️  RECOMMENDED FIX OPTIONS:\n');
    console.log('Option 1: Delete all checklists associated with this unknown shift');
    console.log('  - Simple and clean');
    console.log('  - Will remove these checklists from all dates');
    console.log('  - Completed work will be lost from history\n');
    
    console.log('Option 2: Reassign checklists to an existing shift');
    console.log('  - Preserves completed work');
    console.log('  - Need to identify the correct shift to reassign to');
    console.log('  - More complex\n');
    
    console.log('Option 3: Recreate the shift document');
    console.log('  - Preserves all data');
    console.log('  - Need to know the correct schedule (days of week)');
    console.log('  - Most complex\n');
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

analyzeUnknownShift();
