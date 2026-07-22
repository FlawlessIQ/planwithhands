const admin = require('firebase-admin');
const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function checkMissingServerChecklists() {
  const orgId = 'FErQ4pkcrCovJ7T6L13M';
  const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
  
  console.log('🔍 Check Missing Server Checklists for Chickies');
  console.log('===============================================\n');
  
  try {
    // 1. Check all checklist templates for Chickies
    console.log('📋 ALL CHECKLIST TEMPLATES for Chickies:');
    const templatesSnapshot = await db.collection('organizations').doc(orgId)
      .collection('checklist_templates')
      .where('locationIds', 'array-contains', chickiesLocationId)
      .get();
    
    console.log(`Found ${templatesSnapshot.docs.length} templates for Chickies\n`);
    
    const serverTemplates = [];
    const preDinnerTemplates = [];
    
    templatesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const name = data.name || 'Unknown';
      const jobTypes = data.jobTypes || data.jobType || [];
      
      console.log(`📋 ${name} (${doc.id})`);
      console.log(`   Job Types: ${JSON.stringify(jobTypes)}`);
      
      // Check if it's for Servers
      if (Array.isArray(jobTypes) && jobTypes.some(jt => jt.toLowerCase().includes('server'))) {
        serverTemplates.push({id: doc.id, name, jobTypes});
      }
      
      // Check if it's Pre Dinner related
      if (name.toLowerCase().includes('pre dinner') || name.toLowerCase().includes('pre-dinner')) {
        preDinnerTemplates.push({id: doc.id, name, jobTypes});
      }
      
      console.log('');
    });
    
    console.log(`🎯 ANALYSIS:`);
    console.log(`📋 Templates with "Server" job type: ${serverTemplates.length}`);
    serverTemplates.forEach(t => console.log(`   - ${t.name} (${t.jobTypes.join(', ')})`));
    
    console.log(`\n📋 Pre Dinner templates: ${preDinnerTemplates.length}`);
    preDinnerTemplates.forEach(t => console.log(`   - ${t.name} (${t.jobTypes.join(', ')})`));
    
    // 2. Check which templates are assigned to the Pre Dinner shift
    console.log(`\n🔄 PRE DINNER SHIFT ANALYSIS:`);
    const preDinnerShiftId = 'JLo4mc11PpjK9HOdRcdV';
    const shiftDoc = await db.collection('organizations').doc(orgId)
      .collection('shifts').doc(preDinnerShiftId).get();
    
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      const assignedTemplates = shiftData.checklistTemplateIds || [];
      
      console.log(`Shift: ${shiftData.shiftName}`);
      console.log(`Assigned templates: ${assignedTemplates.length}`);
      
      assignedTemplates.forEach(templateId => {
        const template = templatesSnapshot.docs.find(doc => doc.id === templateId);
        if (template) {
          const data = template.data();
          const name = data.name || 'Unknown';
          const jobTypes = data.jobTypes || [];
          console.log(`   - ${name} (${jobTypes.join(', ')})`);
        } else {
          console.log(`   - ${templateId} (template not found)`);
        }
      });
      
      // Check if there's a Server template that should be assigned
      const serverTemplateForPreDinner = serverTemplates.find(t => 
        t.name.toLowerCase().includes('pre dinner') || 
        t.name.toLowerCase().includes('server') && t.name.toLowerCase().includes('pre')
      );
      
      if (serverTemplateForPreDinner && !assignedTemplates.includes(serverTemplateForPreDinner.id)) {
        console.log(`\n❌ MISSING: "${serverTemplateForPreDinner.name}" should be assigned to Pre Dinner shift!`);
        console.log(`   Template ID: ${serverTemplateForPreDinner.id}`);
      }
      
    } else {
      console.log('❌ Pre Dinner shift not found!');
    }
    
    console.log(`\n💡 SOLUTION:`);
    if (serverTemplates.length === 0) {
      console.log('1. Create Server checklist templates for Chickies');
    } else {
      console.log('1. Assign existing Server templates to the Pre Dinner shift');
      console.log('2. OR verify the user has the correct job type (Busser or Manager)');
    }
    
  } catch (error) {
    console.error('❌ Error checking missing server checklists:', error);
  }
}

checkMissingServerChecklists().then(() => {
  console.log('\n✅ Debug complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});