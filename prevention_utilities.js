const { getDB, admin } = require('./firebase_config');

const db = getDB();

/**
 * Prevention utilities to validate data before writes
 * These functions should be integrated into the app's data layer
 */

/**
 * Validate that all templates in a shift belong to the same location(s) as the shift
 */
async function validateShiftTemplateAssignment(orgId, shiftData, templateIds) {
  console.log('🔒 Validating shift template assignment...');
  
  if (!shiftData.locationIds || shiftData.locationIds.length === 0) {
    throw new Error('Shift must have at least one location assigned');
  }

  if (!templateIds || templateIds.length === 0) {
    return { valid: true, message: 'No templates to validate' };
  }

  const shiftLocationIds = shiftData.locationIds;
  const invalidTemplates = [];

  // Check each template
  for (const templateId of templateIds) {
    try {
      const templateDoc = await db.collection('organizations').doc(orgId)
        .collection('checklist_templates').doc(templateId).get();
      
      if (!templateDoc.exists) {
        invalidTemplates.push({
          templateId,
          reason: 'Template does not exist',
          severity: 'HIGH'
        });
        continue;
      }

      const templateData = templateDoc.data();
      const templateLocationIds = templateData.locationIds || [];

      if (templateLocationIds.length === 0) {
        invalidTemplates.push({
          templateId,
          templateName: templateData.name,
          reason: 'Template has no location assigned',
          severity: 'MEDIUM'
        });
        continue;
      }

      // Check if template location overlaps with shift location
      const hasLocationOverlap = shiftLocationIds.some(shiftLoc => 
        templateLocationIds.includes(shiftLoc)
      );

      if (!hasLocationOverlap) {
        invalidTemplates.push({
          templateId,
          templateName: templateData.name,
          templateLocations: templateLocationIds,
          shiftLocations: shiftLocationIds,
          reason: 'Template location does not match shift location',
          severity: 'HIGH'
        });
      }
    } catch (error) {
      invalidTemplates.push({
        templateId,
        reason: `Error checking template: ${error.message}`,
        severity: 'HIGH'
      });
    }
  }

  if (invalidTemplates.length > 0) {
    const highSeverity = invalidTemplates.filter(t => t.severity === 'HIGH');
    if (highSeverity.length > 0) {
      throw new Error(`Invalid template assignments found: ${JSON.stringify(invalidTemplates, null, 2)}`);
    } else {
      console.warn('⚠️ Template assignment warnings:', invalidTemplates);
    }
  }

  return { valid: true, message: 'All template assignments are valid' };
}

/**
 * Validate checklist assignment to shift
 */
async function validateChecklistShiftAssignment(orgId, checklistData, shiftId) {
  console.log('🔒 Validating checklist shift assignment...');
  
  if (!checklistData.locationIds || checklistData.locationIds.length === 0) {
    throw new Error('Checklist must have at least one location assigned');
  }

  if (!shiftId) {
    return { valid: true, message: 'No shift assignment to validate' };
  }

  try {
    const shiftDoc = await db.collection('organizations').doc(orgId)
      .collection('shifts').doc(shiftId).get();
    
    if (!shiftDoc.exists) {
      throw new Error(`Shift ${shiftId} does not exist`);
    }

    const shiftData = shiftDoc.data();
    const shiftLocationIds = shiftData.locationIds || [];

    if (shiftLocationIds.length === 0) {
      throw new Error('Target shift has no location assigned');
    }

    // Check if checklist location overlaps with shift location
    const hasLocationOverlap = checklistData.locationIds.some(checklistLoc => 
      shiftLocationIds.includes(checklistLoc)
    );

    if (!hasLocationOverlap) {
      throw new Error(`Checklist locations [${checklistData.locationIds.join(', ')}] do not match shift locations [${shiftLocationIds.join(', ')}]`);
    }

    return { valid: true, message: 'Checklist assignment is valid' };
  } catch (error) {
    throw new Error(`Validation failed: ${error.message}`);
  }
}

/**
 * Safe shift update function with validation
 */
async function safeUpdateShift(orgId, shiftId, updateData) {
  console.log(`🛡️ Safely updating shift ${shiftId}...`);
  
  try {
    // If updating template assignments, validate them
    if (updateData.checklistTemplateIds) {
      // Get current shift data
      const shiftDoc = await db.collection('organizations').doc(orgId)
        .collection('shifts').doc(shiftId).get();
      
      if (!shiftDoc.exists) {
        throw new Error(`Shift ${shiftId} does not exist`);
      }

      const currentShiftData = shiftDoc.data();
      const mergedShiftData = { ...currentShiftData, ...updateData };
      
      await validateShiftTemplateAssignment(orgId, mergedShiftData, updateData.checklistTemplateIds);
    }

    // Perform the update
    await db.collection('organizations').doc(orgId)
      .collection('shifts').doc(shiftId).update(updateData);
    
    console.log('✅ Shift updated successfully with validation');
    return { success: true };
  } catch (error) {
    console.error('❌ Shift update failed validation:', error.message);
    throw error;
  }
}

/**
 * Safe checklist assignment function with validation
 */
async function safeAssignChecklistToShift(orgId, checklistId, shiftId, collectionPath = null) {
  console.log(`🛡️ Safely assigning checklist ${checklistId} to shift ${shiftId}...`);
  
  try {
    // Determine collection path if not provided
    if (!collectionPath) {
      const today = new Date().toISOString().split('T')[0];
      collectionPath = `organizations/${orgId}/dailyChecklists/${today}/checklists`;
    }

    // Get checklist data
    const checklistDoc = await db.collection(collectionPath).doc(checklistId).get();
    if (!checklistDoc.exists) {
      throw new Error(`Checklist ${checklistId} does not exist`);
    }

    const checklistData = checklistDoc.data();
    
    // Validate the assignment
    await validateChecklistShiftAssignment(orgId, checklistData, shiftId);

    // Perform the assignment
    await db.collection(collectionPath).doc(checklistId).update({
      assignedShiftId: shiftId,
      lastModified: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✅ Checklist assigned successfully with validation');
    return { success: true };
  } catch (error) {
    console.error('❌ Checklist assignment failed validation:', error.message);
    throw error;
  }
}

/**
 * Audit function to check for potential issues before they become problems
 */
async function auditDataIntegrity(orgId) {
  console.log(`🔍 Auditing data integrity for organization ${orgId}...`);
  
  const warnings = [];
  const errors = [];

  try {
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      throw new Error(`Organization ${orgId} does not exist`);
    }

    // Check locations
    const locationsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('locations').get();
    
    const locations = {};
    locationsSnapshot.forEach(doc => {
      const data = doc.data();
      locations[doc.id] = data;
      
      if (!data.name || data.name.trim() === '') {
        warnings.push(`Location ${doc.id} has no name`);
      }
    });

    console.log(`  📍 Found ${Object.keys(locations).length} locations`);

    // Check templates
    const templatesSnapshot = await db.collection('organizations').doc(orgId)
      .collection('checklist_templates').get();
    
    const templates = {};
    templatesSnapshot.forEach(doc => {
      const data = doc.data();
      templates[doc.id] = data;
      
      if (!data.locationIds || data.locationIds.length === 0) {
        warnings.push(`Template "${data.name}" (${doc.id}) has no location assigned`);
      } else {
        // Check if assigned locations exist
        data.locationIds.forEach(locId => {
          if (!locations[locId]) {
            errors.push(`Template "${data.name}" assigned to non-existent location ${locId}`);
          }
        });
      }
    });

    console.log(`  📋 Found ${Object.keys(templates).length} templates`);

    // Check shifts
    const shiftsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('shifts').get();
    
    shiftsSnapshot.forEach(doc => {
      const data = doc.data();
      const shiftName = data._shiftName || data.shiftName || doc.id;
      
      if (!data.locationIds || data.locationIds.length === 0) {
        warnings.push(`Shift "${shiftName}" has no location assigned`);
      } else {
        // Check if assigned locations exist
        data.locationIds.forEach(locId => {
          if (!locations[locId]) {
            errors.push(`Shift "${shiftName}" assigned to non-existent location ${locId}`);
          }
        });
      }

      // Check template assignments
      if (data.checklistTemplateIds) {
        data.checklistTemplateIds.forEach(templateId => {
          const template = templates[templateId];
          if (!template) {
            errors.push(`Shift "${shiftName}" references non-existent template ${templateId}`);
          } else {
            // Check location consistency
            const shiftLocationIds = data.locationIds || [];
            const templateLocationIds = template.locationIds || [];
            
            const hasLocationOverlap = shiftLocationIds.some(shiftLoc => 
              templateLocationIds.includes(shiftLoc)
            );

            if (!hasLocationOverlap && templateLocationIds.length > 0 && shiftLocationIds.length > 0) {
              errors.push(`Shift "${shiftName}" (locations: ${shiftLocationIds.join(',')}) has template "${template.name}" from different locations (${templateLocationIds.join(',')})`);
            }
          }
        });
      }
    });

    console.log(`  ⏰ Found ${shiftsSnapshot.size} shifts`);

    // Report results
    console.log('\n📊 AUDIT RESULTS:');
    console.log(`  Warnings: ${warnings.length}`);
    console.log(`  Errors: ${errors.length}`);

    if (warnings.length > 0) {
      console.log('\n⚠️ WARNINGS:');
      warnings.forEach((warning, index) => {
        console.log(`  ${index + 1}. ${warning}`);
      });
    }

    if (errors.length > 0) {
      console.log('\n❌ ERRORS:');
      errors.forEach((error, index) => {
        console.log(`  ${index + 1}. ${error}`);
      });
    }

    if (warnings.length === 0 && errors.length === 0) {
      console.log('✅ No issues found!');
    }

    return { warnings, errors, hasIssues: warnings.length > 0 || errors.length > 0 };

  } catch (error) {
    console.error('❌ Audit failed:', error.message);
    return { error: error.message };
  }
}

module.exports = {
  validateShiftTemplateAssignment,
  validateChecklistShiftAssignment,
  safeUpdateShift,
  safeAssignChecklistToShift,
  auditDataIntegrity
};

// If run directly, audit a specific org
if (require.main === module) {
  const orgId = process.argv[2];
  if (!orgId) {
    console.log('Usage: node prevention_utilities.js <orgId>');
    process.exit(1);
  }

  auditDataIntegrity(orgId).then(result => {
    if (result.error) {
      console.error('Audit failed:', result.error);
      process.exit(1);
    } else if (result.hasIssues) {
      console.log('Audit completed with issues found.');
      process.exit(1);
    } else {
      console.log('Audit completed successfully!');
      process.exit(0);
    }
  });
}