const {Firestore} = require('@google-cloud/firestore');

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || 'planwithhands';
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

async function checkLakesideConfig() {
  const orgId = 'B2BXqRWWSUMvbmJEkRBe';
  const locId = 'lakesideBBQQSMYYcZWiWKYDGNT9';
  
  console.log('\n=== CHECKING LAKESIDE BBQ CONFIGURATION ===\n');
  
  try {
    // Check organization
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization not found!');
      return;
    }
    
    const orgData = orgDoc.data();
    console.log('Organization:');
    console.log(`  Name: ${orgData.name || 'N/A'}`);
    console.log(`  Timezone: ${orgData.timezone || 'NOT SET'}`);
    console.log('');
    
    // Check location
    const locDoc = await db
      .collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locId)
      .get();
    
    if (!locDoc.exists) {
      console.log('❌ Location not found!');
      console.log('Let me list all locations...\n');
      const locsSnap = await db
        .collection('organizations')
        .doc(orgId)
        .collection('locations')
        .get();
      console.log(`Found ${locsSnap.size} locations:`);
      locsSnap.docs.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${data.locationName || doc.id}: ${doc.id}`);
        console.log(`    Timezone: ${data.timezone || orgData.timezone || 'NOT SET'}`);
      });
      return;
    }
    
    const locData = locDoc.data();
    console.log('Location:');
    console.log(`  Name: ${locData.locationName || 'N/A'}`);
    console.log(`  ID: ${locId}`);
    console.log(`  Timezone: ${locData.timezone || orgData.timezone || 'NOT SET'}`);
    console.log(`  Address: ${locData.address || 'N/A'}`);
    console.log('');
    
    // Check shifts
    const shiftsSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('shifts')
      .get();
    
    console.log(`Shifts: ${shiftsSnap.size} total`);
    shiftsSnap.docs.forEach(doc => {
      const data = doc.data();
      const locIds = data.locationIds || [];
      if (locIds.includes(locId)) {
        console.log(`  ✅ ${data.shiftName || doc.id}: ${doc.id}`);
        console.log(`     Days: ${JSON.stringify(data.daysOfWeek || [])}`);
        console.log(`     Time: ${data.startTime || '?'} - ${data.endTime || '?'}`);
        console.log(`     Templates: ${data.checklistTemplateIds?.length || 0}`);
      }
    });
    console.log('');
    
    // Check templates
    const templatesSnap = await db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .get();
    
    let relevantTemplates = 0;
    console.log('Templates:');
    templatesSnap.docs.forEach(doc => {
      const data = doc.data();
      const locIds = data.locationIds || [];
      if (locIds.length === 0 || locIds.includes(locId)) {
        relevantTemplates++;
        console.log(`  ✅ ${data.name || doc.id}: ${doc.id}`);
        console.log(`     Locations: ${JSON.stringify(locIds)}`);
      }
    });
    console.log(`  Total relevant templates: ${relevantTemplates}`);
    console.log('');
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  
  process.exit(0);
}

checkLakesideConfig();
