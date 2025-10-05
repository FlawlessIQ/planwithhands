#!/usr/bin/env node

/**
 * Check all real organizations for Unknown Template issues
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with correct database
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkAllOrgsForUnknownTemplates() {
  console.log('🔍 Checking all organizations for Unknown Template issues...');
  
  try {
    // Get all organizations
    const orgsSnap = await db.collection('organizations').get();
    console.log(`📊 Checking ${orgsSnap.docs.length} organizations`);
    
    let totalProblematicChecklists = 0;
    
    for (const orgDoc of orgsSnap.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.name || orgData.organizationName || orgId;
      
      console.log(`\n🏢 Checking org: ${orgName} (${orgId})`);
      
      // Get locations for this org
      const locationsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      
      if (locationsSnap.docs.length === 0) {
        console.log('   📍 No locations found');
        continue;
      }
      
      for (const locDoc of locationsSnap.docs) {
        const locationId = locDoc.id;
        const locationData = locDoc.data();
        const locationName = locationData.locationName || locationId;
        
        // Get recent checklists from last week
        const weekAgo = new Date();
        weekAgo.setDate(weekAgo.getDate() - 7);
        const weekAgoString = weekAgo.toISOString().split('T')[0];
        
        const checklistsSnap = await db
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .where('date', '>=', weekAgoString)
          .get();
        
        if (checklistsSnap.docs.length === 0) continue;
        
        console.log(`   📍 Location: ${locationName} (${checklistsSnap.docs.length} recent checklists)`);
        
        for (const checklistDoc of checklistsSnap.docs) {
          const checklistData = checklistDoc.data();
          const templateName = checklistData.templateName || '';
          const templateIds = checklistData.checklistTemplateIds || [];
          
          let isProblematic = false;
          let issues = [];
          
          // Check for Unknown Template in name
          if (templateName.toLowerCase().includes('unknown template')) {
            isProblematic = true;
            issues.push(`templateName: "${templateName}"`);
          }
          
          // Check for missing template IDs
          if (templateIds.length === 0) {
            isProblematic = true;
            issues.push('no template IDs');
          }
          
          // Check for invalid template IDs
          const invalidTemplateIds = [];
          for (const templateId of templateIds) {
            try {
              const templateDoc = await db
                .collection('organizations')
                .doc(orgId)
                .collection('checklist_templates')
                .doc(templateId)
                .get();
              
              if (!templateDoc.exists) {
                invalidTemplateIds.push(`${templateId} (not found)`);
              } else {
                const templateData = templateDoc.data();
                const name = (templateData.name || '').toString().trim();
                if (!name || name.toLowerCase() === 'unknown template') {
                  invalidTemplateIds.push(`${templateId} (invalid name: "${name}")`);
                }
              }
            } catch (err) {
              invalidTemplateIds.push(`${templateId} (error)`);
            }
          }
          
          if (invalidTemplateIds.length > 0) {
            isProblematic = true;
            issues.push(`invalid templates: [${invalidTemplateIds.join(', ')}]`);
          }
          
          if (isProblematic) {
            totalProblematicChecklists++;
            console.log(`     ❌ PROBLEMATIC: ${checklistDoc.id}`);
            console.log(`        Date: ${checklistData.date}`);
            console.log(`        Shift: ${checklistData.shiftId}`);
            console.log(`        Issues: ${issues.join('; ')}`);
          }
        }
      }
    }
    
    console.log(`\n📊 Summary: Found ${totalProblematicChecklists} problematic checklists across all organizations`);
    
    if (totalProblematicChecklists > 0) {
      console.log('\n💡 To clean up these issues:');
      console.log('   1. The Cloud Function fix is being deployed to prevent new issues');
      console.log('   2. Run cleanup script to remove existing problematic checklists');
      console.log('   3. Redeploy web app to apply client-side fixes');
    }
    
  } catch (error) {
    console.error('❌ Error checking organizations:', error);
  }
}

// Run the check
checkAllOrgsForUnknownTemplates().then(() => {
  console.log('🏁 Check complete');
  process.exit(0);
});