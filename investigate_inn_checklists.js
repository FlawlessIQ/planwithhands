const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'plan-with-hands',
});

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function investigateInnChecklists() {
  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const today = '2025-10-12';
    
    console.log('🔍 Investigating (Inn) checklists across all locations...\n');
    
    // Get all locations
    const locationsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('locations')
      .get();
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationData = locationDoc.data();
      const locationName = locationData.name || 'Unknown';
      
      console.log(`\n📍 ${locationName} (${locationDoc.id})`);
      console.log(`${'='.repeat(80)}\n`);
      
      // Get today's checklists
      const checklistsSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationDoc.id)
        .collection('daily_checklists')
        .where('date', '==', today)
        .get();
      
      console.log(`Checklists for today: ${checklistsSnapshot.docs.length}\n`);
      
      // Look for checklists with "Inn" in the name
      const innChecklists = [];
      let totalInnCarryForward = 0;
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || '';
        
        if (templateName.toLowerCase().includes('inn')) {
          const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
          const carryForwardTasks = tasksSnapshot.docs.filter(d => 
            d.data().isCarryForward === true
          );
          
          innChecklists.push({
            name: templateName,
            totalTasks: tasksSnapshot.docs.length,
            carryForwardTasks: carryForwardTasks.length,
            normalTasks: tasksSnapshot.docs.length - carryForwardTasks.length,
          });
          
          totalInnCarryForward += carryForwardTasks.length;
        }
      }
      
      if (innChecklists.length > 0) {
        console.log('📋 Checklists with "Inn" in name:\n');
        innChecklists.forEach(c => {
          console.log(`  ${c.name}`);
          console.log(`    Total tasks: ${c.totalTasks}`);
          console.log(`    Normal tasks: ${c.normalTasks}`);
          console.log(`    Carry-forward tasks: ${c.carryForwardTasks}`);
        });
        console.log(`\n  Total carry-forward in Inn checklists: ${totalInnCarryForward}\n`);
      } else {
        console.log('No checklists with "Inn" in name found.\n');
      }
      
      // Also check for templates in this location
      const templatesSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('locations').doc(locationDoc.id)
        .collection('checklist_templates')
        .get();
      
      console.log(`Templates: ${templatesSnapshot.docs.length}`);
      const innTemplates = templatesSnapshot.docs.filter(d => 
        (d.data().name || '').toLowerCase().includes('inn')
      );
      
      if (innTemplates.length > 0) {
        console.log('\n🎯 Templates with "Inn" in name:');
        innTemplates.forEach(t => {
          console.log(`  - ${t.data().name}`);
        });
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error(error.stack);
  } finally {
    process.exit(0);
  }
}

investigateInnChecklists();
