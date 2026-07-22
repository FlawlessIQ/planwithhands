// Check jobTypes on shifts and templates
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();
db.settings({
  databaseId: 'planwithhands'
});

async function main() {
  console.log('🔍 Checking JobTypes on Shifts and Templates');
  console.log('Organization: 3qjYzHagWmfbnMieJ1aj');
  console.log('═'.repeat(80));

  const orgId = '3qjYzHagWmfbnMieJ1aj';
  
  // Get all shifts
  console.log('\n🔄 Shifts:');
  const shiftsSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('shifts')
    .get();
  
  console.log(`  Found ${shiftsSnap.size} shifts`);
  for (const shift of shiftsSnap.docs) {
    const data = shift.data();
    const jobTypes = data.jobTypes || data.jobType;
    console.log(`\n    Shift: ${data.shiftName || 'Unnamed'} (${shift.id})`);
    console.log(`      JobTypes: ${jobTypes ? JSON.stringify(jobTypes) : '(EMPTY)'}`);
    console.log(`      Templates: ${JSON.stringify(data.checklistTemplateIds || [])}`);
  }

  // Get all checklist templates
  console.log('\n\n📋 Checklist Templates:');
  const templatesSnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('checklist_templates')
    .get();
  
  console.log(`  Found ${templatesSnap.size} templates`);
  for (const tmpl of templatesSnap.docs) {
    const data = tmpl.data();
    const jobTypes = data.jobTypes || data.jobType;
    console.log(`\n    Template: ${data.name || 'Unnamed'} (${tmpl.id})`);
    console.log(`      JobTypes: ${jobTypes ? JSON.stringify(jobTypes) : '(EMPTY)'}`);
    console.log(`      Locations: ${JSON.stringify(data.locationIds || [])}`);
    console.log(`      Active: ${data.active !== false}`);
    console.log(`      Deleted: ${data.deleted === true}`);
  }

  console.log('\n' + '═'.repeat(80));
  console.log('🎯 Solution:');
  console.log('  If shifts have jobTypes but templates don\'t, we need to copy');
  console.log('  jobTypes from shift → checklist when creating daily checklists.');
  console.log('═'.repeat(80));
  
  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
