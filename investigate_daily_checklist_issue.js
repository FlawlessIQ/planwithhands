const { getDB, admin } = require('./firebase_config');

const db = getDB();

async function investigateDailyChecklistIssue() {
  console.log('🔍 Investigating daily checklist assignment issue...');
  console.log('='.repeat(60));

  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = 'fW45ffBBPar5EaNodDYq'; // Hamilton Pork
    const shiftId = 'oPoQG161AQCaWxMZu9Ch'; // (Pork) PRE DINNER SERVICE
    const today = '2025-09-29';

    console.log(`\n🔍 CHECKING DAILY CHECKLISTS:`);
    console.log(`   Organization: ${orgId}`);
    console.log(`   Location: ${locationId} (Hamilton Pork)`);
    console.log(`   Shift: ${shiftId} ((Pork) PRE DINNER SERVICE)`);
    console.log(`   Date: ${today}`);

    // Check different possible paths where daily checklists might be stored
    const possiblePaths = [
      `organizations/${orgId}/dailyChecklists/${today}/checklists`,
      `organizations/${orgId}/locations/${locationId}/daily_checklists`,
      `organizations/${orgId}/locations/${locationId}/shifts/${shiftId}/checklists`,
      `organizations/${orgId}/today`,
      `organizations/${orgId}/todayChecklists`
    ];

    for (const path of possiblePaths) {
      try {
        console.log(`\n📁 Checking collection: ${path}`);
        const snapshot = await db.collection(path).get();
        
        if (snapshot.size > 0) {
          console.log(`   Found ${snapshot.size} documents`);
          
          snapshot.forEach(async (doc) => {
            const data = doc.data();
            const docId = doc.id;
            const name = data.checklistName || data.templateName || data.name || 'NO NAME';
            const templateId = data.templateId || data.checklistTemplateId;
            const assignedShiftId = data.assignedShiftId;
            const locationIds = data.locationIds || [];
            
            // Check if this is one of the problematic checklists
            if (name.startsWith('C ') && (assignedShiftId === shiftId || docId.includes(shiftId))) {
              console.log(`   🚨 PROBLEMATIC CHECKLIST FOUND:`);
              console.log(`      Document ID: ${docId}`);
              console.log(`      Name: "${name}"`);
              console.log(`      Template ID: ${templateId}`);
              console.log(`      Assigned Shift: ${assignedShiftId}`);
              console.log(`      Location IDs: [${locationIds.join(', ')}]`);
              console.log(`      Date: ${data.date || data.dateString || 'NO DATE'}`);
              
              // Get the template details
              if (templateId) {
                try {
                  const templateDoc = await db.collection('organizations').doc(orgId)
                    .collection('checklist_templates').doc(templateId).get();
                  
                  if (templateDoc.exists) {
                    const templateData = templateDoc.data();
                    const templateLocationIds = templateData.locationIds || [];
                    console.log(`      Template Location IDs: [${templateLocationIds.join(', ')}]`);
                    
                    // Check if template location matches checklist assignment
                    if (!templateLocationIds.includes(locationId)) {
                      console.log(`      ❌ MISMATCH: Template belongs to different location!`);
                    }
                  }
                } catch (error) {
                  console.log(`      ❌ Error fetching template: ${error.message}`);
                }
              }
              console.log('');
            }
          });
        } else {
          console.log(`   No documents found`);
        }
      } catch (error) {
        console.log(`   Error accessing collection: ${error.message}`);
      }
    }

    // Check shift configuration
    console.log(`\n⚙️ CHECKING SHIFT CONFIGURATION:`);
    const shiftDoc = await db.collection('organizations').doc(orgId)
      .collection('shifts').doc(shiftId).get();
    
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      const shiftName = shiftData._shiftName || shiftData.shiftName;
      const shiftLocationIds = shiftData.locationIds || [];
      const templateIds = shiftData.checklistTemplateIds || [];
      
      console.log(`   Shift Name: "${shiftName}"`);
      console.log(`   Shift Location IDs: [${shiftLocationIds.join(', ')}]`);
      console.log(`   Template IDs: [${templateIds.join(', ')}]`);
      
      // Check each template
      for (const templateId of templateIds) {
        try {
          const templateDoc = await db.collection('organizations').doc(orgId)
            .collection('checklist_templates').doc(templateId).get();
          
          if (templateDoc.exists) {
            const templateData = templateDoc.data();
            const templateName = templateData.name;
            const templateLocationIds = templateData.locationIds || [];
            
            console.log(`   Template: "${templateName}" (${templateId})`);
            console.log(`     Template Location IDs: [${templateLocationIds.join(', ')}]`);
            
            if (templateName.startsWith('C ')) {
              console.log(`     🚨 CHICKIES TEMPLATE ASSIGNED TO HAMILTON PORK SHIFT!`);
            }
          }
        } catch (error) {
          console.log(`   Error fetching template ${templateId}: ${error.message}`);
        }
      }
    }

  } catch (error) {
    console.error('❌ Investigation failed:', error);
  }
}

investigateDailyChecklistIssue();