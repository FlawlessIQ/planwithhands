const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');

async function previewSystematicFix() {
  console.log('👀 PREVIEW MODE - NO CHANGES WILL BE MADE');
  console.log('This shows what would be fixed without making any changes');
  console.log('=' .repeat(100));
  
  const report = {
    totalOrgs: 0,
    orgsWithIssues: 0,
    totalShifts: 0,
    shiftsWithIssues: 0,
    invalidTemplateReferences: 0,
    wouldFixShifts: 0
  };
  
  try {
    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();
    report.totalOrgs = orgsSnapshot.size;
    
    console.log(`Found ${orgsSnapshot.size} organizations to analyze`);
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      
      console.log(`\n🏢 Organization: ${orgId} (${orgData.name || 'Unnamed'})`);
      
      try {
        // Get templates
        const templatesSnapshot = await db.collection('organizations').doc(orgId)
          .collection('checklist_templates').get();
        
        const validTemplateIds = new Set();
        const templateNames = new Map();
        
        templatesSnapshot.docs.forEach(templateDoc => {
          const templateData = templateDoc.data();
          validTemplateIds.add(templateDoc.id);
          templateNames.set(templateDoc.id, templateData.name || 'Unnamed');
        });
        
        console.log(`  📋 Templates: ${validTemplateIds.size}`);
        if (validTemplateIds.size > 0) {
          console.log(`      Available templates:`);
          Array.from(templateNames.entries()).slice(0, 5).forEach(([id, name]) => {
            console.log(`        - "${name}" (${id})`);
          });
          if (templateNames.size > 5) {
            console.log(`        ... and ${templateNames.size - 5} more`);
          }
        }
        
        // Get shifts
        const shiftsSnapshot = await db.collection('organizations').doc(orgId)
          .collection('shifts').get();
        
        report.totalShifts += shiftsSnapshot.size;
        console.log(`  ⏰ Shifts: ${shiftsSnapshot.size}`);
        
        let orgHasIssues = false;
        
        for (const shiftDoc of shiftsSnapshot.docs) {
          const shiftData = shiftDoc.data();
          const shiftName = shiftData.name || shiftData.shiftName || 'Unnamed';
          const templateIds = shiftData.checklistTemplateIds || [];
          
          // Validate template IDs
          const invalidIds = templateIds.filter(id => !validTemplateIds.has(id));
          const validIds = templateIds.filter(id => validTemplateIds.has(id));
          
          if (invalidIds.length > 0) {
            if (!orgHasIssues) {
              console.log(`\n      🚨 ISSUES FOUND:`);
              orgHasIssues = true;
            }
            
            console.log(`\n        ❌ Shift: "${shiftName}"`);
            console.log(`           Current templates: ${templateIds.length}`);
            console.log(`           Invalid: ${invalidIds.length} -> ${JSON.stringify(invalidIds)}`);
            console.log(`           Valid: ${validIds.length} -> ${JSON.stringify(validIds)}`);
            
            // Determine what fix would be applied
            let proposedFix = [];
            if (validIds.length >= 2) {
              proposedFix = validIds;
              console.log(`           🔧 WOULD FIX: Keep ${validIds.length} valid templates`);
            } else if (validTemplateIds.size > 0) {
              proposedFix = Array.from(validTemplateIds).slice(0, 3);
              console.log(`           🔧 WOULD FIX: Use ${proposedFix.length} org templates`);
            } else {
              proposedFix = [];
              console.log(`           🔧 WOULD FIX: Remove all (no templates exist)`);
            }
            
            console.log(`           📋 Proposed templates: ${JSON.stringify(proposedFix)}`);
            
            report.shiftsWithIssues++;
            report.invalidTemplateReferences += invalidIds.length;
            report.wouldFixShifts++;
          }
        }
        
        if (orgHasIssues) {
          report.orgsWithIssues++;
        } else {
          console.log(`      ✅ All shifts have valid template references`);
        }
        
      } catch (orgError) {
        console.log(`  ❌ Error analyzing organization: ${orgError.message}`);
      }
    }
    
    // Generate preview report
    console.log('\n' + '=' .repeat(100));
    console.log('📊 PREVIEW REPORT - WHAT WOULD BE FIXED');
    console.log('=' .repeat(100));
    
    console.log(`Organizations to scan: ${report.totalOrgs}`);
    console.log(`Organizations with issues: ${report.orgsWithIssues}`);
    console.log(`Total shifts: ${report.totalShifts}`);
    console.log(`Shifts with invalid templates: ${report.shiftsWithIssues}`);
    console.log(`Invalid template references: ${report.invalidTemplateReferences}`);
    console.log(`Shifts that would be fixed: ${report.wouldFixShifts}`);
    
    console.log(`\n💡 IMPACT ASSESSMENT:`);
    if (report.shiftsWithIssues > 0) {
      console.log(`✅ Fixing these issues would:`);
      console.log(`  - Stop ${report.shiftsWithIssues} shifts from generating "Unknown Template" checklists`);
      console.log(`  - Remove ${report.invalidTemplateReferences} invalid template references`);
      console.log(`  - Improve daily checklist generation reliability`);
      console.log(`  - Clean up dashboard analytics data`);
      
      console.log(`\n🚀 NEXT STEPS:`);
      console.log(`1. Review the proposed fixes above`);
      console.log(`2. Run the full systematic_template_fix.js script to apply fixes`);
      console.log(`3. Monitor tomorrow's checklist generation`);
      console.log(`4. Clean up existing invalid checklists`);
    } else {
      console.log(`🎉 No template reference issues found across all organizations!`);
    }
    
  } catch (error) {
    console.error('❌ Error during preview:', error);
  }
  
  process.exit(0);
}

previewSystematicFix();