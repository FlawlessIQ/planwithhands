/**
 * Find currently active "Unknown Template" checklists
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
// Use the correct database
db.settings({ databaseId: 'planwithhands' });

async function findUnknownTemplateChecklists() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const locationId = 'fW45ffBBPar5EaNodDYq';
  const shiftId = 'VY0xGrIzvHSaqX1AXkcY';

  console.log('\n=== FINDING UNKNOWN TEMPLATE CHECKLISTS ===\n');

  try {
    // Get recent checklists for this location
    const recentChecklistsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    console.log(`Found ${recentChecklistsSnap.size} recent checklists\n`);

    const problemChecklists = [];
    const okChecklists = [];

    for (const doc of recentChecklistsSnap.docs) {
      const data = doc.data();
      const hasName = data.templateName && data.templateName.trim() !== '';
      
      if (hasName) {
        okChecklists.push({
          id: doc.id,
          date: data.date,
          templateName: data.templateName,
          templateId: data.checklistTemplateId,
          shiftId: data.shiftId
        });
      } else {
        problemChecklists.push({
          id: doc.id,
          date: data.date,
          templateId: data.checklistTemplateId,
          shiftId: data.shiftId,
          createdBy: data.createdBy,
          createdAt: data.createdAt?.toDate()
        });
      }
    }

    console.log(`OK Checklists (have template names): ${okChecklists.length}`);
    console.log(`Problem Checklists (missing template names): ${problemChecklists.length}\n`);

    if (problemChecklists.length > 0) {
      console.log('❌ PROBLEM CHECKLISTS:\n');
      problemChecklists.forEach(c => {
        console.log(`  Checklist: ${c.id}`);
        console.log(`    Date: ${c.date}`);
        console.log(`    Template ID: ${c.templateId || '(missing)'}`);
        console.log(`    Shift ID: ${c.shiftId}`);
        console.log(`    Created by: ${c.createdBy}`);
        console.log(`    Created at: ${c.createdAt || '(unknown)'}`);
        console.log('');
      });

      // Get unique template IDs
      const templateIds = [...new Set(problemChecklists.map(c => c.templateId).filter(id => id))];
      
      if (templateIds.length > 0) {
        console.log('\n📋 Checking these template IDs:\n');
        
        for (const templateId of templateIds) {
          const templateDoc = await db
            .collection('organizations')
            .doc(orgId)
            .collection('checklist_templates')
            .doc(templateId)
            .get();

          if (templateDoc.exists) {
            const data = templateDoc.data();
            console.log(`  Template ${templateId}:`);
            console.log(`    Name: ${data.name || '❌ (MISSING)'}`);
            console.log(`    Active: ${data.active !== false ? 'Yes' : '❌ No'}`);
            console.log(`    Deleted: ${data.deleted === true ? '❌ Yes' : 'No'}`);
            console.log('');
          } else {
            console.log(`  Template ${templateId}: ❌ NOT FOUND (deleted from database)\n`);
          }
        }
      }

      // Check the shift configuration
      console.log('\n⚙️ SHIFT CONFIGURATION:\n');
      const shiftDoc = await db
        .collection('organizations')
        .doc(orgId)
        .collection('shifts')
        .doc(shiftId)
        .get();

      if (shiftDoc.exists) {
        const shiftData = shiftDoc.data();
        console.log(`Shift: ${shiftData.shiftName} (${shiftId})`);
        console.log(`Template IDs in shift: ${JSON.stringify(shiftData.checklistTemplateIds || [])}`);
        console.log('');

        // Check each template in the shift
        const shiftTemplateIds = shiftData.checklistTemplateIds || [];
        console.log('Validating each template in the shift:\n');
        
        for (const templateId of shiftTemplateIds) {
          const templateDoc = await db
            .collection('organizations')
            .doc(orgId)
            .collection('checklist_templates')
            .doc(templateId)
            .get();

          if (!templateDoc.exists) {
            console.log(`  ❌ ${templateId}: Template does not exist`);
            console.log(`     Action: Remove this ID from shift.checklistTemplateIds\n`);
          } else {
            const data = templateDoc.data();
            const issues = [];
            
            if (!data.name || data.name.trim() === '') {
              issues.push('NO NAME');
            }
            if (data.deleted === true) {
              issues.push('DELETED');
            }
            if (data.active === false) {
              issues.push('INACTIVE');
            }

            if (issues.length > 0) {
              console.log(`  ❌ ${templateId}: ${data.name || '(no name)'}`);
              console.log(`     Issues: ${issues.join(', ')}`);
              console.log(`     Action: ${data.deleted ? 'Remove from shift' : 'Fix template or remove from shift'}\n`);
            } else {
              console.log(`  ✅ ${templateId}: ${data.name} (OK)\n`);
            }
          }
        }
      } else {
        console.log(`Shift ${shiftId}: NOT FOUND\n`);
      }
    } else {
      console.log('✅ No problem checklists found!');
    }

    if (okChecklists.length > 0 && okChecklists.length <= 10) {
      console.log('\n✅ Recent OK checklists:\n');
      okChecklists.forEach(c => {
        console.log(`  ${c.date}: ${c.templateName} (${c.templateId})`);
      });
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

findUnknownTemplateChecklists()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
