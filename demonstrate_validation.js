const {Firestore} = require('@google-cloud/firestore');
const db = new Firestore({databaseId: 'planwithhands'});

/**
 * Visual demonstration of template validation logic
 */
async function demonstrateValidation() {
  console.log('='.repeat(70));
  console.log('DAILY GENERATOR TEMPLATE VALIDATION DEMONSTRATION');
  console.log('='.repeat(70));
  console.log();

  // Simulate what the generator sees
  const testCases = [
    {name: 'Kitchen Opening', valid: true, reason: 'Valid name'},
    {name: 'Bar Closing', valid: true, reason: 'Valid name'},
    {name: '', valid: false, reason: 'Empty name'},
    {name: '   ', valid: false, reason: 'Whitespace only'},
    {name: 'Unknown Template', valid: false, reason: 'Explicitly rejected'},
    {name: 'unknown template', valid: false, reason: 'Case-insensitive match'},
    {name: 'UNKNOWN TEMPLATE', valid: false, reason: 'Case-insensitive match'},
    {name: null, valid: false, reason: 'Null name'},
    {name: undefined, valid: false, reason: 'Undefined name'},
  ];

  console.log('Template Validation Rules:');
  console.log('-'.repeat(70));
  
  testCases.forEach((testCase, index) => {
    const displayName = testCase.name === null ? 'null' :
                       testCase.name === undefined ? 'undefined' :
                       testCase.name === '' ? '(empty string)' :
                       `"${testCase.name}"`;
    
    const status = testCase.valid ? '✅ PASS' : '❌ REJECT';
    console.log(`${index + 1}. ${status} | ${displayName.padEnd(25)} | ${testCase.reason}`);
  });

  console.log();
  console.log('='.repeat(70));
  console.log('ACTUAL DATABASE SCAN');
  console.log('='.repeat(70));
  console.log();

  try {
    const orgsSnap = await db.collection('organizations').get();
    let totalTemplates = 0;
    let validTemplates = 0;
    let invalidTemplates = 0;
    const orgStats = [];

    for (const orgDoc of orgsSnap.docs) {
      const templatesSnap = await orgDoc.ref.collection('checklist_templates').get();
      let orgValid = 0;
      let orgInvalid = 0;

      for (const tDoc of templatesSnap.docs) {
        totalTemplates++;
        const data = tDoc.data() || {};
        const name = (data.name || '').toString().trim();
        
        if (!name || name.toLowerCase() === 'unknown template') {
          invalidTemplates++;
          orgInvalid++;
        } else {
          validTemplates++;
          orgValid++;
        }
      }

      if (templatesSnap.size > 0) {
        orgStats.push({
          orgId: orgDoc.id,
          total: templatesSnap.size,
          valid: orgValid,
          invalid: orgInvalid,
        });
      }
    }

    console.log(`Organizations scanned: ${orgsSnap.size}`);
    console.log(`Total templates: ${totalTemplates}`);
    console.log();
    
    console.log('Templates by Organization:');
    console.log('-'.repeat(70));
    orgStats.forEach(stat => {
      const statusIcon = stat.invalid === 0 ? '✅' : '⚠️';
      console.log(`${statusIcon} ${stat.orgId.substring(0, 20).padEnd(22)} | Total: ${stat.total.toString().padStart(3)} | Valid: ${stat.valid.toString().padStart(3)} | Invalid: ${stat.invalid}`);
    });

    console.log();
    console.log('='.repeat(70));
    console.log('SUMMARY');
    console.log('='.repeat(70));
    console.log();
    console.log(`✅ Valid templates:   ${validTemplates}`);
    console.log(`❌ Invalid templates: ${invalidTemplates}`);
    console.log();
    
    if (invalidTemplates === 0) {
      console.log('🎉 SUCCESS: All templates pass validation!');
      console.log('   The daily generator will not create any "Unknown Template" checklists.');
    } else {
      console.log('⚠️  WARNING: Invalid templates detected!');
      console.log('   Run cleanup to remove templates with invalid names.');
    }
    
    console.log();
    console.log('Validation implemented in: functions/src/dailyGenerator.ts');
    console.log('Function: fetchValidTemplates()');
    console.log();

  } catch (err) {
    console.error('Error scanning database:', err);
    process.exit(1);
  }

  process.exit(0);
}

demonstrateValidation();
