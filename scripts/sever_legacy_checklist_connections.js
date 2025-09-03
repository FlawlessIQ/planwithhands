#!/usr/bin/env node

/**
 * Legacy Checklist Migration Script
 * 
 * This script addresses the issue where old checklists were duplicated across all locations
 * and deleting one would delete all others. It creates location-specific copies of legacy
 * checklists and updates all related shift associations.
 * 
 * Usage:
 *   node scripts/sever_legacy_checklist_connections.js --org=YOUR_ORG_ID [--dry-run] [--help]
 * 
 * Options:
 *   --org=ID        Organization ID to process (required)
 *   --dry-run       Show what would be done without making changes
 *   --help          Show this help message
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Parse command line arguments
const args = process.argv.slice(2);
const options = {
  organizationId: null,
  dryRun: false,
  help: false
};

for (const arg of args) {
  if (arg.startsWith('--org=')) {
    options.organizationId = arg.split('=')[1];
  } else if (arg === '--dry-run') {
    options.dryRun = true;
  } else if (arg === '--help' || arg === '-h') {
    options.help = true;
  }
}

// Show help
if (options.help) {
  console.log(`
Legacy Checklist Migration Script

This script fixes the issue where legacy checklists are linked across all locations,
preventing independent deletion. It creates location-specific copies and updates
all related shift associations.

Usage:
  node scripts/sever_legacy_checklist_connections.js --org=YOUR_ORG_ID [--dry-run]

Options:
  --org=ID        Organization ID to process (required)
  --dry-run       Show what would be done without making changes
  --help          Show this help message

Example:
  node scripts/sever_legacy_checklist_connections.js --org=abc123 --dry-run
  node scripts/sever_legacy_checklist_connections.js --org=abc123
`);
  process.exit(0);
}

// Validate required arguments
if (!options.organizationId) {
  console.error('❌ Error: Organization ID is required. Use --org=YOUR_ORG_ID');
  console.error('Use --help for more information.');
  process.exit(1);
}

/**
 * Get all locations for the organization
 */
async function getAvailableLocations(organizationId) {
  try {
    console.log('📍 Fetching available locations...');
    
    const locationsSnapshot = await db
      .collection('organizations')
      .doc(organizationId)
      .collection('locations')
      .get();

    const locations = locationsSnapshot.docs.map(doc => ({
      id: doc.id,
      name: doc.data().name || doc.data().locationName || 'Unnamed Location',
      ...doc.data()
    }));

    console.log(`   Found ${locations.length} locations:`);
    locations.forEach(loc => console.log(`   - ${loc.name} (${loc.id})`));
    
    return locations;
  } catch (error) {
    console.error('❌ Error fetching locations:', error.message);
    throw error;
  }
}

/**
 * Find problematic (legacy) checklist templates
 */
async function findProblematicChecklists(organizationId) {
  try {
    console.log('🔍 Scanning for problematic checklists...');
    
    const templatesSnapshot = await db
      .collection('organizations')
      .doc(organizationId)
      .collection('checklist_templates')
      .get();

    const problematic = [];

    for (const doc of templatesSnapshot.docs) {
      const data = doc.data();
      
      // Skip already migrated templates
      if (data.migratedToLocationSpecific === true || data.archived === true) {
        continue;
      }

      // Consider problematic if:
      // 1. No locationIds field (legacy)
      // 2. Empty locationIds array
      // 3. locationIds contains multiple locations (was duplicated)
      const locationIds = data.locationIds || [];
      const isProblematic = !Array.isArray(locationIds) || 
                           locationIds.length === 0 || 
                           locationIds.length > 1;

      if (isProblematic) {
        problematic.push({
          id: doc.id,
          name: data.name || data.checklistName || 'Unnamed Template',
          description: data.description || '',
          locationIds: locationIds,
          data: data
        });
      }
    }

    console.log(`   Found ${problematic.length} problematic checklist(s):`);
    problematic.forEach(checklist => {
      console.log(`   - "${checklist.name}" (${checklist.id})`);
      console.log(`     Location IDs: [${checklist.locationIds.join(', ') || 'none'}]`);
    });

    return problematic;
  } catch (error) {
    console.error('❌ Error scanning checklists:', error.message);
    throw error;
  }
}

/**
 * Copy tasks from original template to new location-specific template
 */
async function copyTasks(organizationId, originalTemplateId, newTemplateId, locationName) {
  try {
    // Get tasks from original template
    const originalTasksSnapshot = await db
      .collection('organizations')
      .doc(organizationId)
      .collection('checklist_templates')
      .doc(originalTemplateId)
      .collection('tasks')
      .get();

    if (originalTasksSnapshot.empty) {
      console.log(`     No tasks to copy for ${locationName}`);
      return;
    }

    console.log(`     Copying ${originalTasksSnapshot.docs.length} tasks to ${locationName}...`);

    // Copy tasks in batches
    const batch = db.batch();
    let operationCount = 0;

    for (const taskDoc of originalTasksSnapshot.docs) {
      const taskRef = db
        .collection('organizations')
        .doc(organizationId)
        .collection('checklist_templates')
        .doc(newTemplateId)
        .collection('tasks')
        .doc(taskDoc.id);

      const taskData = {
        ...taskDoc.data(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        migratedFrom: `${originalTemplateId}/${taskDoc.id}`
      };

      batch.set(taskRef, taskData);
      operationCount++;

      // Commit in batches of 400 to stay under Firestore limits
      if (operationCount >= 400) {
        await batch.commit();
        operationCount = 0;
      }
    }

    // Commit remaining operations
    if (operationCount > 0) {
      await batch.commit();
    }

    console.log(`     ✅ Copied tasks for ${locationName}`);
  } catch (error) {
    console.error(`     ❌ Error copying tasks for ${locationName}:`, error.message);
    throw error;
  }
}

/**
 * Update shift associations to use new location-specific templates
 */
async function updateShiftAssociations(organizationId, originalTemplateId, locationToTemplateMap) {
  try {
    console.log('🔄 Updating shift associations...');
    
    // Get all shifts that reference the original template
    const shiftsSnapshot = await db
      .collection('organizations')
      .doc(organizationId)
      .collection('shifts')
      .where('checklistTemplateIds', 'array-contains', originalTemplateId)
      .get();

    console.log(`   Found ${shiftsSnapshot.docs.length} shifts to update`);

    const batch = db.batch();
    let updateCount = 0;

    for (const shiftDoc of shiftsSnapshot.docs) {
      const shiftData = shiftDoc.data();
      const checklistTemplateIds = [...(shiftData.checklistTemplateIds || [])];
      
      // Get shift location IDs (handle both old and new formats)
      let shiftLocationIds = [];
      if (Array.isArray(shiftData.locationIds)) {
        shiftLocationIds = shiftData.locationIds;
      } else if (shiftData.locationId) {
        shiftLocationIds = [shiftData.locationId];
      }

      if (checklistTemplateIds.includes(originalTemplateId)) {
        // Remove original template ID
        const originalIndex = checklistTemplateIds.indexOf(originalTemplateId);
        if (originalIndex > -1) {
          checklistTemplateIds.splice(originalIndex, 1);
        }

        // Add location-specific template IDs for this shift's locations
        for (const locationId of shiftLocationIds) {
          const newTemplateId = locationToTemplateMap[locationId];
          if (newTemplateId && !checklistTemplateIds.includes(newTemplateId)) {
            checklistTemplateIds.push(newTemplateId);
          }
        }

        // Update the shift
        batch.update(shiftDoc.ref, {
          checklistTemplateIds: checklistTemplateIds,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          migratedChecklistIds: admin.firestore.FieldValue.arrayUnion(originalTemplateId)
        });

        updateCount++;
        console.log(`   - Updated "${shiftData.shiftName}" for locations: [${shiftLocationIds.join(', ')}]`);
      }
    }

    if (updateCount > 0) {
      await batch.commit();
      console.log(`   ✅ Updated ${updateCount} shifts`);
    } else {
      console.log('   No shifts needed updates');
    }
  } catch (error) {
    console.error('❌ Error updating shift associations:', error.message);
    throw error;
  }
}

/**
 * Process a single problematic checklist
 */
async function processChecklist(checklist, availableLocations, organizationId, dryRun) {
  const { id: originalTemplateId, name, data: originalData } = checklist;
  
  console.log(`\n📋 Processing: "${name}" (${originalTemplateId})`);
  
  if (dryRun) {
    console.log('   [DRY RUN] Would create location-specific copies:');
    availableLocations.forEach(location => {
      const newId = `${originalTemplateId}_${location.id}`;
      console.log(`   - "${name} (${location.name})" -> ${newId}`);
    });
    return { success: true, newTemplateIds: [], locationToTemplateMap: {} };
  }

  const batch = db.batch();
  const newTemplateIds = [];
  const locationToTemplateMap = {};

  // Create location-specific copies
  for (const location of availableLocations) {
    const locationSpecificId = `${originalTemplateId}_${location.id}`;
    const locationSpecificRef = db
      .collection('organizations')
      .doc(organizationId)
      .collection('checklist_templates')
      .doc(locationSpecificId);

    const locationSpecificData = {
      ...originalData,
      name: `${name} (${location.name})`,
      checklistName: `${name} (${location.name})`,
      locationIds: [location.id],
      originalTemplateId: originalTemplateId,
      migratedFrom: originalTemplateId,
      createdFromMigration: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    batch.set(locationSpecificRef, locationSpecificData);
    newTemplateIds.push(locationSpecificId);
    locationToTemplateMap[location.id] = locationSpecificId;

    console.log(`   ✨ Will create: "${name} (${location.name})" -> ${locationSpecificId}`);
  }

  // Commit the new templates
  try {
    await batch.commit();
    console.log(`   ✅ Created ${newTemplateIds.length} location-specific templates`);

    // Copy tasks to each new template
    for (let i = 0; i < availableLocations.length; i++) {
      const location = availableLocations[i];
      const newTemplateId = newTemplateIds[i];
      await copyTasks(organizationId, originalTemplateId, newTemplateId, location.name);
    }

    // Archive the original template (don't delete, keep for reference)
    const originalRef = db
      .collection('organizations')
      .doc(organizationId)
      .collection('checklist_templates')
      .doc(originalTemplateId);

    await originalRef.update({
      migratedToLocationSpecific: true,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      archived: true,
      replacedBy: newTemplateIds
    });

    console.log(`   ✅ Archived original template: ${originalTemplateId}`);

    return { success: true, newTemplateIds, locationToTemplateMap };
  } catch (error) {
    console.error(`   ❌ Error processing checklist "${name}":`, error.message);
    return { success: false, newTemplateIds: [], locationToTemplateMap: {} };
  }
}

/**
 * Main migration function
 */
async function performMigration() {
  try {
    console.log('🚀 Starting Legacy Checklist Migration');
    console.log('=====================================\n');
    console.log(`Organization ID: ${options.organizationId}`);
    console.log(`Mode: ${options.dryRun ? 'DRY RUN (no changes will be made)' : 'LIVE MIGRATION'}\n`);

    // Get available locations
    const availableLocations = await getAvailableLocations(options.organizationId);
    
    if (availableLocations.length === 0) {
      console.log('⚠️  No locations found. Cannot proceed with migration.');
      return;
    }

    // Find problematic checklists
    const problematicChecklists = await findProblematicChecklists(options.organizationId);
    
    if (problematicChecklists.length === 0) {
      console.log('🎉 No problematic checklists found. All checklists are properly configured!');
      return;
    }

    console.log(`\n📊 Migration Summary:`);
    console.log(`   • ${problematicChecklists.length} checklist(s) to migrate`);
    console.log(`   • ${availableLocations.length} location(s) available`);
    console.log(`   • ${problematicChecklists.length * availableLocations.length} new templates will be created\n`);

    // Confirmation prompt for live migration
    if (!options.dryRun) {
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });

      const answer = await new Promise(resolve => {
        rl.question('⚠️  This will permanently modify your data. Continue? (type "yes" to confirm): ', resolve);
      });

      rl.close();

      if (answer.toLowerCase() !== 'yes') {
        console.log('Migration cancelled.');
        return;
      }
    }

    // Process each checklist
    const allLocationToTemplateMaps = {};
    let successCount = 0;

    for (const checklist of problematicChecklists) {
      const result = await processChecklist(checklist, availableLocations, options.organizationId, options.dryRun);
      
      if (result.success) {
        successCount++;
        // Merge location mappings for shift updates
        Object.assign(allLocationToTemplateMaps, result.locationToTemplateMap);
      }
    }

    // Update shift associations (only in live mode and if we have successful migrations)
    if (!options.dryRun && successCount > 0) {
      for (const checklist of problematicChecklists) {
        await updateShiftAssociations(options.organizationId, checklist.id, allLocationToTemplateMaps);
      }
    } else if (options.dryRun) {
      console.log('\n🔄 [DRY RUN] Would update shift associations for all processed checklists');
    }

    // Final summary
    console.log('\n📋 Migration Complete!');
    console.log('====================');
    
    if (options.dryRun) {
      console.log('✅ Dry run completed successfully');
      console.log(`   Would have processed ${problematicChecklists.length} checklist(s)`);
      console.log(`   Would have created ${problematicChecklists.length * availableLocations.length} new templates`);
      console.log('\nTo perform the actual migration, run the same command without --dry-run');
    } else {
      console.log(`✅ Successfully migrated ${successCount}/${problematicChecklists.length} checklist(s)`);
      console.log(`   Created ${successCount * availableLocations.length} location-specific templates`);
      console.log(`   Updated shift associations`);
      console.log(`   Archived ${successCount} original templates`);
    }

  } catch (error) {
    console.error('\n❌ Migration failed:', error.message);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

// Run the migration
performMigration()
  .then(() => {
    console.log('\n🎉 All done!');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Unexpected error:', error);
    process.exit(1);
  });
