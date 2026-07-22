/**
 * Investigate a specific "Unknown Template" checklist
 * 
 * This will trace back through:
 * 1. The checklist document
 * 2. Its template references
 * 3. The shift configuration that created it
 * 4. Whether those templates exist and are valid
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function investigateChecklist() {
  // From your example
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const locationId = 'fW45ffBBPar5EaNodDYq';
  const checklistId = 'FErQ4pkcrCovJ7T6L13M_fW45ffBBPar5EaNodDYq_VY0xGrIzvHSaqX1AXkcY_2025-10-03';
  const shiftId = 'VY0xGrIzvHSaqX1AXkcY';

  const templateIds = [
    'Ezuho3cKjbKv4MZR59dU',
    'H8NR6hf2KQtl9rGHsNzR',
    'cFv5sR9JZd220cjv6g3O',
    'fXYrAHM462QbGiW7sZWl'
  ];

  console.log('\n=== INVESTIGATING UNKNOWN TEMPLATE CHECKLIST ===\n');
  console.log(`Checklist ID: ${checklistId}`);
  console.log(`Shift ID: ${shiftId}`);
  console.log(`Template IDs from checklist: ${templateIds.join(', ')}\n`);

  try {
    // Check the checklist itself
    console.log('1. Checking the checklist document...\n');
    const checklistRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .doc(checklistId);

    const checklistDoc = await checklistRef.get();
    
    if (checklistDoc.exists) {
      const data = checklistDoc.data();
      console.log('✅ Checklist found:');
      console.log(`   Date: ${data.date}`);
      console.log(`   Created by: ${data.createdBy}`);
      console.log(`   Template Name: ${data.templateName || '(MISSING)'}`);
      console.log(`   Template ID: ${data.checklistTemplateId || '(MISSING)'}`);
      console.log(`   Shift ID: ${data.shiftId}`);
      
      // Check if it has an array of template IDs
      if (data.checklistTemplateIds) {
        console.log(`   Template IDs (array): ${JSON.stringify(data.checklistTemplateIds)}`);
      }
    } else {
      console.log('❌ Checklist document not found');
      return;
    }

    // Check the shift configuration
    console.log('\n2. Checking the shift configuration...\n');
    const shiftRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .doc(shiftId);

    const shiftDoc = await shiftRef.get();
    
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      console.log('✅ Shift found:');
      console.log(`   Name: ${shiftData.shiftName}`);
      console.log(`   Template IDs: ${JSON.stringify(shiftData.checklistTemplateIds || [])}`);
      console.log(`   Location IDs: ${JSON.stringify(shiftData.locationIds || shiftData.locationId || [])}`);
      console.log(`   Repeats Daily: ${shiftData.repeatsDaily}`);
      console.log(`   Active Days: ${JSON.stringify(shiftData.activeDays || shiftData.days || [])}`);
    } else {
      console.log('❌ Shift not found');
    }

    // Check each template
    console.log('\n3. Checking each template...\n');
    
    for (const templateId of templateIds) {
      const templateRef = db
        .collection('organizations')
        .doc(orgId)
        .collection('checklist_templates')
        .doc(templateId);

      const templateDoc = await templateRef.get();
      
      if (templateDoc.exists) {
        const data = templateDoc.data();
        const issues = [];
        
        if (!data.name || data.name.trim() === '') issues.push('NO NAME');
        if (data.deleted === true) issues.push('DELETED');
        if (data.active === false) issues.push('INACTIVE');
        
        const locationIds = Array.isArray(data.locationIds) 
          ? data.locationIds 
          : (data.locationId ? [data.locationId] : []);
        
        if (locationIds.length > 0 && !locationIds.includes(locationId)) {
          issues.push('WRONG LOCATION');
        }

        if (issues.length > 0) {
          console.log(`❌ Template ${templateId}:`);
          console.log(`   Name: ${data.name || '(MISSING)'}`);
          console.log(`   Issues: ${issues.join(', ')}`);
          console.log(`   Location IDs: ${JSON.stringify(locationIds)}`);
          console.log(`   Active: ${data.active}`);
          console.log(`   Deleted: ${data.deleted}`);
        } else {
          console.log(`✅ Template ${templateId}:`);
          console.log(`   Name: ${data.name}`);
          console.log(`   Status: Valid`);
        }
      } else {
        console.log(`❌ Template ${templateId}: NOT FOUND (deleted from database)`);
      }
    }

    // Find ALL checklists being generated with missing template names
    console.log('\n4. Finding all checklists with missing template names...\n');
    
    const allChecklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .where('date', '>=', '2025-10-01')
      .where('date', '<=', '2025-10-03')
      .get();

    const problemChecklists = [];
    
    for (const doc of allChecklistsSnap.docs) {
      const data = doc.data();
      if (!data.templateName || data.templateName.trim() === '') {
        problemChecklists.push({
          id: doc.id,
          date: data.date,
          templateId: data.checklistTemplateId,
          shiftId: data.shiftId,
          createdBy: data.createdBy
        });
      }
    }

    if (problemChecklists.length > 0) {
      console.log(`Found ${problemChecklists.length} checklists with missing template names:`);
      problemChecklists.forEach(c => {
        console.log(`  - ${c.id}`);
        console.log(`    Date: ${c.date}, Created by: ${c.createdBy}, Template: ${c.templateId}`);
      });
    } else {
      console.log('✅ No checklists with missing template names found in the last 3 days');
    }

    // Recommendations
    console.log('\n=== RECOMMENDATIONS ===\n');
    console.log('To fix this issue:\n');
    console.log('1. The code changes have been applied to prevent future unknown template checklists');
    console.log('2. Update the shift configuration to remove invalid template IDs');
    console.log('3. Delete existing checklists with missing template names');
    console.log('\nTo delete the problem checklist, run:');
    console.log(`   firebase firestore:delete "organizations/${orgId}/locations/${locationId}/daily_checklists/${checklistId}" --recursive`);

  } catch (error) {
    console.error('Error investigating checklist:', error);
  }
}

investigateChecklist()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
