const { getDB, admin } = require('./firebase_config');

const db = getDB();

/**
 * Comprehensive validation script to check for cross-location assignment issues
 * This should be run regularly (daily/weekly) to catch issues early
 */
async function validateLocationConsistency() {
  console.log('🔍 Running location consistency validation...');
  console.log('=' .repeat(60));

  const issues = [];
  let totalOrgsChecked = 0;
  let totalShiftsChecked = 0;
  let totalChecklistsChecked = 0;

  try {
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    console.log(`\n📊 Found ${orgsSnapshot.size} organizations to check`);

    for (const orgDoc of orgsSnapshot.docs) {
      const orgData = orgDoc.data();
      const orgId = orgDoc.id;
      const orgName = orgData.name || orgData.organizationName || `Org-${orgId.slice(0, 8)}`;
      
      console.log(`\n🏢 Checking organization: ${orgName} (${orgId})`);
      totalOrgsChecked++;

      try {
        // Get all locations for this org
        const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
        const locations = {};
        
        locationsSnapshot.forEach(doc => {
          const data = doc.data();
          locations[doc.id] = {
            name: data.name || 'Unnamed Location',
            ...data
          };
        });

        console.log(`  📍 Found ${Object.keys(locations).length} locations`);

        // Get all templates for this org
        const templatesSnapshot = await db.collection('organizations').doc(orgId).collection('checklist_templates').get();
        const templates = {};
        
        templatesSnapshot.forEach(doc => {
          const data = doc.data();
          templates[doc.id] = {
            name: data.name || 'Unnamed Template',
            locationIds: data.locationIds || [],
            ...data
          };
        });

        console.log(`  📋 Found ${Object.keys(templates).length} templates`);

        // Check all shifts for this org
        const shiftsSnapshot = await db.collection('organizations').doc(orgId).collection('shifts').get();
        console.log(`  ⏰ Found ${shiftsSnapshot.size} shifts to validate`);

        shiftsSnapshot.forEach(shiftDoc => {
          const shiftData = shiftDoc.data();
          const shiftId = shiftDoc.id;
          const shiftName = shiftData._shiftName || shiftData.shiftName || 'Unnamed Shift';
          const shiftLocationIds = shiftData.locationIds || [];
          
          totalShiftsChecked++;

          // Check if shift has valid location
          if (shiftLocationIds.length === 0) {
            issues.push({
              type: 'SHIFT_NO_LOCATION',
              severity: 'HIGH',
              orgId,
              orgName,
              shiftId,
              shiftName,
              description: 'Shift has no location assigned'
            });
          }

          // Check each template in the shift
          const templateIds = shiftData.checklistTemplateIds || [];
          templateIds.forEach(templateId => {
            const template = templates[templateId];
            
            if (!template) {
              issues.push({
                type: 'TEMPLATE_NOT_FOUND',
                severity: 'HIGH',
                orgId,
                orgName,
                shiftId,
                shiftName,
                templateId,
                description: `Template ${templateId} referenced in shift but doesn't exist`
              });
              return;
            }

            // Check if template location matches shift location
            const templateLocationIds = template.locationIds || [];
            const hasLocationMismatch = !shiftLocationIds.some(shiftLoc => 
              templateLocationIds.includes(shiftLoc)
            );

            if (hasLocationMismatch && templateLocationIds.length > 0 && shiftLocationIds.length > 0) {
              const shiftLocationNames = shiftLocationIds.map(id => locations[id]?.name || id).join(', ');
              const templateLocationNames = templateLocationIds.map(id => locations[id]?.name || id).join(', ');

              issues.push({
                type: 'CROSS_LOCATION_ASSIGNMENT',
                severity: 'HIGH',
                orgId,
                orgName,
                shiftId,
                shiftName,
                templateId,
                templateName: template.name,
                shiftLocations: shiftLocationNames,
                templateLocations: templateLocationNames,
                description: `Template "${template.name}" (${templateLocationNames}) assigned to shift "${shiftName}" (${shiftLocationNames})`
              });
            }
          });
        });

        // Check today's checklist instances for cross-location assignments
        const today = new Date();
        const todayString = today.toISOString().split('T')[0];
        
        const checklistCollections = [
          `organizations/${orgId}/today`,
          `organizations/${orgId}/todayChecklists`,
          `organizations/${orgId}/dailyChecklists/${todayString}/checklists`
        ];

        for (const collectionPath of checklistCollections) {
          try {
            const checklistSnapshot = await db.collection(collectionPath).get();
            
            checklistSnapshot.forEach(checklistDoc => {
              const checklistData = checklistDoc.data();
              const checklistId = checklistDoc.id;
              const checklistName = checklistData.name || 'Unnamed Checklist';
              const checklistLocationIds = checklistData.locationIds || [];
              const assignedShiftId = checklistData.assignedShiftId;
              
              totalChecklistsChecked++;

              if (assignedShiftId) {
                // Find the shift this checklist is assigned to
                const assignedShift = shiftsSnapshot.docs.find(s => s.id === assignedShiftId);
                if (assignedShift) {
                  const assignedShiftData = assignedShift.data();
                  const assignedShiftLocationIds = assignedShiftData.locationIds || [];
                  
                  // Check if checklist location matches assigned shift location
                  const hasLocationMismatch = !checklistLocationIds.some(checklistLoc => 
                    assignedShiftLocationIds.includes(checklistLoc)
                  );

                  if (hasLocationMismatch && checklistLocationIds.length > 0 && assignedShiftLocationIds.length > 0) {
                    const checklistLocationNames = checklistLocationIds.map(id => locations[id]?.name || id).join(', ');
                    const shiftLocationNames = assignedShiftLocationIds.map(id => locations[id]?.name || id).join(', ');

                    issues.push({
                      type: 'CHECKLIST_WRONG_SHIFT',
                      severity: 'MEDIUM',
                      orgId,
                      orgName,
                      checklistId,
                      checklistName,
                      assignedShiftId,
                      assignedShiftName: assignedShiftData._shiftName || assignedShiftData.shiftName,
                      checklistLocations: checklistLocationNames,
                      shiftLocations: shiftLocationNames,
                      collection: collectionPath,
                      description: `Checklist "${checklistName}" (${checklistLocationNames}) assigned to shift at different location (${shiftLocationNames})`
                    });
                  }
                } else {
                  issues.push({
                    type: 'CHECKLIST_ORPHANED_SHIFT',
                    severity: 'MEDIUM',
                    orgId,
                    orgName,
                    checklistId,
                    checklistName,
                    assignedShiftId,
                    description: `Checklist assigned to non-existent shift ${assignedShiftId}`
                  });
                }
              }
            });
          } catch (error) {
            // Collection might not exist, which is fine
          }
        }

      } catch (error) {
        console.error(`  ❌ Error checking org ${orgName}:`, error.message);
        issues.push({
          type: 'ORG_CHECK_ERROR',
          severity: 'LOW',
          orgId,
          orgName,
          description: `Error checking organization: ${error.message}`
        });
      }
    }

    // Generate report
    console.log('\n' + '='.repeat(60));
    console.log('📊 VALIDATION REPORT');
    console.log('='.repeat(60));
    
    console.log(`\n📈 Statistics:`);
    console.log(`  Organizations checked: ${totalOrgsChecked}`);
    console.log(`  Shifts checked: ${totalShiftsChecked}`);
    console.log(`  Checklists checked: ${totalChecklistsChecked}`);
    console.log(`  Total issues found: ${issues.length}`);

    if (issues.length === 0) {
      console.log('\n✅ NO ISSUES FOUND! All location assignments are consistent.');
      return { success: true, issues: [], stats: { totalOrgsChecked, totalShiftsChecked, totalChecklistsChecked } };
    }

    // Group issues by severity
    const highSeverityIssues = issues.filter(i => i.severity === 'HIGH');
    const mediumSeverityIssues = issues.filter(i => i.severity === 'MEDIUM');
    const lowSeverityIssues = issues.filter(i => i.severity === 'LOW');

    console.log(`\n🚨 HIGH SEVERITY ISSUES (${highSeverityIssues.length}):`);
    highSeverityIssues.forEach((issue, index) => {
      console.log(`  ${index + 1}. [${issue.type}] ${issue.orgName}: ${issue.description}`);
    });

    console.log(`\n⚠️  MEDIUM SEVERITY ISSUES (${mediumSeverityIssues.length}):`);
    mediumSeverityIssues.forEach((issue, index) => {
      console.log(`  ${index + 1}. [${issue.type}] ${issue.orgName}: ${issue.description}`);
    });

    if (lowSeverityIssues.length > 0) {
      console.log(`\n📝 LOW SEVERITY ISSUES (${lowSeverityIssues.length}):`);
      lowSeverityIssues.forEach((issue, index) => {
        console.log(`  ${index + 1}. [${issue.type}] ${issue.orgName}: ${issue.description}`);
      });
    }

    // Recommendations
    console.log('\n💡 RECOMMENDATIONS:');
    if (highSeverityIssues.length > 0) {
      console.log('  🔥 HIGH PRIORITY: Fix cross-location assignments immediately');
      console.log('     - Run the fix script for affected organizations');
      console.log('     - Review template assignment processes');
    }
    if (mediumSeverityIssues.length > 0) {
      console.log('  ⚠️  MEDIUM PRIORITY: Review checklist-to-shift assignments');
      console.log('     - Clean up orphaned or misassigned checklists');
    }
    
    console.log('  📅 ONGOING: Run this validation script daily/weekly');
    console.log('  🛡️  PREVENTION: Implement validation in the app before saving');

    return { 
      success: false, 
      issues, 
      stats: { totalOrgsChecked, totalShiftsChecked, totalChecklistsChecked },
      highSeverityCount: highSeverityIssues.length,
      mediumSeverityCount: mediumSeverityIssues.length,
      lowSeverityCount: lowSeverityIssues.length
    };

  } catch (error) {
    console.error('❌ Validation failed:', error);
    return { success: false, error: error.message };
  }
}

// Export for use in other scripts or Cloud Functions
if (require.main === module) {
  // Run directly
  validateLocationConsistency().then((result) => {
    if (result.success) {
      console.log('\n🎉 Validation completed successfully!');
      process.exit(0);
    } else {
      console.log('\n⚠️  Validation completed with issues found.');
      process.exit(result.highSeverityCount > 0 ? 1 : 0);
    }
  }).catch(error => {
    console.error('Validation script failed:', error);
    process.exit(1);
  });
}

module.exports = { validateLocationConsistency };