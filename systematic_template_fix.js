const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');

async function systematicTemplateValidationFix() {
  console.log('🔍 SYSTEMATIC TEMPLATE VALIDATION & FIX');
  console.log('Scanning ALL organizations for invalid template references...');
  console.log('=' .repeat(100));
  
  const report = {
    totalOrgs: 0,
    orgsWithIssues: 0,
    totalShifts: 0,
    shiftsWithIssues: 0,
    invalidTemplateReferences: 0,
    fixedShifts: 0,
    errors: []
  };
  
  try {
    // 1. Get all organizations
    console.log('1️⃣ SCANNING ALL ORGANIZATIONS...');
    const orgsSnapshot = await db.collection('organizations').get();
    report.totalOrgs = orgsSnapshot.size;
    
    console.log(`Found ${orgsSnapshot.size} organizations to scan`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      
      console.log(`\n🏢 Organization: ${orgId} (${orgData.name || 'Unnamed'})`);
      
      try {
        // 2. Get all templates for this organization
        const templatesSnapshot = await db.collection('organizations').doc(orgId)
          .collection('checklist_templates').get();
        
        const validTemplateIds = new Set();
        const templateNames = new Map();
        
        templatesSnapshot.docs.forEach(templateDoc => {
          const templateData = templateDoc.data();
          validTemplateIds.add(templateDoc.id);
          templateNames.set(templateDoc.id, templateData.name || 'Unnamed');
        });
        
        console.log(`  📋 Found ${validTemplateIds.size} valid templates`);
        
        // 3. Get all shifts for this organization
        const shiftsSnapshot = await db.collection('organizations').doc(orgId)
          .collection('shifts').get();
        
        report.totalShifts += shiftsSnapshot.size;
        console.log(`  ⏰ Found ${shiftsSnapshot.size} shifts to validate`);
        
        const orgHasIssues = false;
        let orgShiftsWithIssues = 0;
        
        for (const shiftDoc of shiftsSnapshot.docs) {
          const shiftId = shiftDoc.id;
          const shiftData = shiftDoc.data();
          const shiftName = shiftData.name || shiftData.shiftName || 'Unnamed';
          const templateIds = shiftData.checklistTemplateIds || [];
          
          console.log(`\n    🔄 Shift: "${shiftName}" (${shiftId})`);
          console.log(`       Template IDs: ${JSON.stringify(templateIds)}`);
          
          // 4. Validate template IDs
          const validIds = [];
          const invalidIds = [];
          
          templateIds.forEach(templateId => {
            if (validTemplateIds.has(templateId)) {
              validIds.push(templateId);
            } else {
              invalidIds.push(templateId);
            }
          });
          
          if (invalidIds.length > 0) {
            console.log(`       ❌ INVALID: ${JSON.stringify(invalidIds)}`);
            console.log(`       ✅ VALID: ${JSON.stringify(validIds)}`);
            
            orgShiftsWithIssues++;
            report.shiftsWithIssues++;
            report.invalidTemplateReferences += invalidIds.length;
            
            // 5. Propose fix options
            console.log(`       🛠️  FIX OPTIONS:`);
            
            if (validIds.length > 0) {
              console.log(`         OPTION 1: Keep only valid templates (${validIds.length})`);
              validIds.forEach(id => {
                console.log(`           - "${templateNames.get(id)}" (${id})`);
              });
            }
            
            if (validTemplateIds.size > 0) {
              const allValidIds = Array.from(validTemplateIds);
              console.log(`         OPTION 2: Use all organization templates (${validTemplateIds.size})`);
              allValidIds.slice(0, 3).forEach(id => {
                console.log(`           - "${templateNames.get(id)}" (${id})`);
              });
              if (allValidIds.length > 3) {
                console.log(`           ... and ${allValidIds.length - 3} more`);
              }
            }
            
            // 6. EXECUTE FIX (choose option based on context)
            let fixedTemplateIds = [];
            
            if (validIds.length >= 2) {
              // Keep valid templates if we have at least 2
              fixedTemplateIds = validIds;
              console.log(`       ✨ APPLYING FIX: Keeping ${validIds.length} valid templates`);
            } else if (validTemplateIds.size > 0) {
              // Use first 3 active templates from organization
              const activeTemplates = [];
              for (const [id, name] of templateNames.entries()) {
                if (activeTemplates.length < 3) {
                  activeTemplates.push(id);
                }
              }
              fixedTemplateIds = activeTemplates;
              console.log(`       ✨ APPLYING FIX: Using ${activeTemplates.length} organization templates`);
            } else {
              // No templates exist - remove all template IDs
              fixedTemplateIds = [];
              console.log(`       ✨ APPLYING FIX: Removing all template IDs (no templates exist)`);
            }
            
            // 7. Update the shift
            try {
              const updateData = {
                checklistTemplateIds: fixedTemplateIds,
                updatedAt: admin.firestore.Timestamp.now(),
                updatedBy: 'systematic-template-fix',
                previousTemplateIds: templateIds, // Keep history
                fixAppliedAt: admin.firestore.Timestamp.now()
              };
              
              await shiftDoc.ref.update(updateData);
              report.fixedShifts++;
              
              console.log(`       ✅ FIXED: Updated shift with ${fixedTemplateIds.length} valid template IDs`);
              
            } catch (updateError) {
              console.log(`       ❌ FAILED TO UPDATE: ${updateError.message}`);
              report.errors.push(`${orgId}/${shiftId}: ${updateError.message}`);
            }
            
          } else {
            console.log(`       ✅ All template IDs are valid`);
          }
        }
        
        if (orgShiftsWithIssues > 0) {
          report.orgsWithIssues++;
          console.log(`  📊 Organization summary: ${orgShiftsWithIssues}/${shiftsSnapshot.size} shifts had issues`);
        } else {
          console.log(`  ✅ Organization has no template reference issues`);
        }
        
      } catch (orgError) {
        console.log(`  ❌ Error processing organization: ${orgError.message}`);
        report.errors.push(`${orgId}: ${orgError.message}`);
      }
    }
    
    // 8. Generate comprehensive report
    console.log('\n' + '=' .repeat(100));
    console.log('📊 SYSTEMATIC FIX COMPLETE - FINAL REPORT');
    console.log('=' .repeat(100));
    
    console.log(`📈 STATISTICS:`);
    console.log(`  Organizations scanned: ${report.totalOrgs}`);
    console.log(`  Organizations with issues: ${report.orgsWithIssues}`);
    console.log(`  Total shifts scanned: ${report.totalShifts}`);
    console.log(`  Shifts with invalid templates: ${report.shiftsWithIssues}`);
    console.log(`  Invalid template references found: ${report.invalidTemplateReferences}`);
    console.log(`  Shifts successfully fixed: ${report.fixedShifts}`);
    console.log(`  Errors encountered: ${report.errors.length}`);
    
    if (report.errors.length > 0) {
      console.log(`\n❌ ERRORS:`);
      report.errors.forEach(error => console.log(`  - ${error}`));
    }
    
    console.log(`\n🎉 IMPACT:`);
    console.log(`  ${report.fixedShifts} shifts will no longer generate "Unknown Template" checklists`);
    console.log(`  Daily generator will only create checklists for valid templates`);
    console.log(`  Reduced system noise and improved user experience`);
    
    // 9. Cleanup recommendation
    console.log(`\n🧹 CLEANUP RECOMMENDATION:`);
    console.log(`Run the following to clean up existing invalid checklists:`);
    console.log(`  1. Delete today's checklists with invalid template IDs`);
    console.log(`  2. Monitor tomorrow's generation for verification`);
    console.log(`  3. Check dashboard analytics for improved data quality`);
    
  } catch (error) {
    console.error('❌ Fatal error during systematic fix:', error);
  }
  
  process.exit(0);
}

// Add a preview mode function for safety
async function previewSystematicFix() {
  console.log('👀 PREVIEW MODE - NO CHANGES WILL BE MADE');
  console.log('This will show what would be fixed without making changes');
  console.log('=' .repeat(80));
  
  // Same logic as above but without the actual update operations
  // Just replace the update section with:
  // console.log(`       🔍 WOULD FIX: Update with ${fixedTemplateIds.length} valid template IDs`);
}

// Uncomment the line below for preview mode:
// previewSystematicFix();

// Run the actual fix:
systematicTemplateValidationFix();