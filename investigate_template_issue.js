const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');
const orgId = '3qjYzHagWmfbnMieJ1aj';
const problemTemplateId = 'aEwRngcnvjSh1glH19oz';

async function investigateTemplateIssue() {
  console.log('🔍 INVESTIGATING TEMPLATE ISSUE');
  console.log(`Organization: ${orgId}`);
  console.log(`Problem Template ID: ${problemTemplateId}`);
  console.log('=' .repeat(80));
  
  try {
    // 1. Check if the problem template exists
    console.log('1️⃣ CHECKING PROBLEM TEMPLATE:');
    const templateRef = db.collection('organizations').doc(orgId)
      .collection('checklist_templates').doc(problemTemplateId);
    const templateSnap = await templateRef.get();
    
    if (templateSnap.exists) {
      const templateData = templateSnap.data();
      console.log(`✅ Template ${problemTemplateId} EXISTS:`);
      console.log(JSON.stringify(templateData, null, 2));
    } else {
      console.log(`❌ Template ${problemTemplateId} does NOT exist`);
    }
    
    // 2. Check all templates in organization
    console.log('\n2️⃣ ALL TEMPLATES IN ORGANIZATION:');
    const templatesSnapshot = await db.collection('organizations').doc(orgId)
      .collection('checklist_templates').get();
    
    console.log(`Found ${templatesSnapshot.size} templates:`);
    templatesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${doc.id}: "${data.name || 'No name'}" (Active: ${data.isActive})`);
    });
    
    // 3. Check shifts and their template assignments
    console.log('\n3️⃣ SHIFTS AND TEMPLATE ASSIGNMENTS:');
    const shiftsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('shifts').get();
    
    console.log(`Found ${shiftsSnapshot.size} shifts:`);
    for (const shiftDoc of shiftsSnapshot.docs) {
      const shiftData = shiftDoc.data();
      const templateIds = shiftData.checklistTemplateIds || [];
      console.log(`  - Shift ${shiftDoc.id}:`);
      console.log(`    Name: ${shiftData.name || 'No name'}`);
      console.log(`    Template IDs: ${JSON.stringify(templateIds)}`);
      
      // Check if this shift references the problem template
      if (templateIds.includes(problemTemplateId)) {
        console.log(`    ⚠️  REFERENCES PROBLEM TEMPLATE ${problemTemplateId}`);
      }
    }
    
    // 4. Check today's generated checklists
    console.log('\n4️⃣ TODAY\'S GENERATED CHECKLISTS:');
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    
    const locationsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('locations').get();
    
    for (const locDoc of locationsSnapshot.docs) {
      const locationId = locDoc.id;
      const locationData = locDoc.data();
      console.log(`\n📍 Location: ${locationData.name || locationId}`);
      
      const checklistsSnapshot = await db.collection('organizations').doc(orgId)
        .collection('locations').doc(locationId)
        .collection('daily_checklists')
        .where('date', '==', today)
        .get();
      
      console.log(`  Today's checklists: ${checklistsSnapshot.size}`);
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateIds = checklistData.checklistTemplateIds || [];
        console.log(`    - ${checklistDoc.id}:`);
        console.log(`      Templates: ${JSON.stringify(templateIds)}`);
        console.log(`      Created: ${checklistData.createdAt?.toDate()}`);
        
        if (templateIds.includes(problemTemplateId)) {
          console.log(`      ⚠️  USES PROBLEM TEMPLATE ${problemTemplateId}`);
        }
      }
    }
    
    // 5. Find the root cause - which shift is configured with the invalid template
    console.log('\n5️⃣ ROOT CAUSE ANALYSIS:');
    console.log('Looking for shifts that reference the invalid template...');
    
    const allShifts = await db.collection('organizations').doc(orgId)
      .collection('shifts').get();
    
    const problematicShifts = [];
    for (const shiftDoc of allShifts.docs) {
      const shiftData = shiftDoc.data();
      const templateIds = shiftData.checklistTemplateIds || [];
      if (templateIds.includes(problemTemplateId)) {
        problematicShifts.push({
          id: shiftDoc.id,
          name: shiftData.name || 'Unnamed',
          templateIds: templateIds
        });
      }
    }
    
    if (problematicShifts.length > 0) {
      console.log(`❌ Found ${problematicShifts.length} shifts referencing invalid template:`);
      problematicShifts.forEach(shift => {
        console.log(`  - Shift "${shift.name}" (${shift.id})`);
        console.log(`    Template IDs: ${JSON.stringify(shift.templateIds)}`);
      });
      
      console.log('\n💡 SOLUTION:');
      console.log('You need to either:');
      console.log(`1. Remove template ID "${problemTemplateId}" from these shifts`);
      console.log(`2. Create a valid template with ID "${problemTemplateId}"`);
      console.log('3. Update shifts to use valid template IDs');
    } else {
      console.log('✅ No shifts found referencing the invalid template');
      console.log('The issue might be in carry-forward logic or elsewhere');
    }
    
  } catch (error) {
    console.error('❌ Error investigating template issue:', error);
  }
  
  process.exit(0);
}

investigateTemplateIssue();