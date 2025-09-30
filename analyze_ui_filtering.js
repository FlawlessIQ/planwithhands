const { getDB, admin } = require('./firebase_config');

const db = getDB();

async function analyzeUIFilteringBehavior() {
  console.log('🔍 Analyzing UI filtering behavior...');
  console.log('='.repeat(60));

  try {
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    
    // Get all locations
    console.log('\n📍 LOCATIONS IN ORG:');
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    const locations = {};
    
    locationsSnapshot.forEach(doc => {
      const data = doc.data();
      locations[doc.id] = data;
      console.log(`  ${doc.id}: "${data.name || 'NO NAME'}"`);
    });

    // Test the filtering logic that should happen in the app
    console.log('\n🔍 TESTING APP FILTERING LOGIC:');
    
    // Test 1: Filter templates for Chickies location only
    console.log('\n1️⃣ Templates that should show for CHICKIES location:');
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
    
    const chickiesTemplatesQuery = await db
      .collection('organizations').doc(orgId)
      .collection('checklist_templates')
      .where('locationIds', 'array-contains', chickiesLocationId)
      .get();
    
    console.log(`   Found ${chickiesTemplatesQuery.size} templates:`);
    chickiesTemplatesQuery.forEach(doc => {
      const data = doc.data();
      console.log(`   ✅ ${data.name} (${doc.id})`);
    });

    // Test 2: Filter templates for Hamilton Pork location only
    console.log('\n2️⃣ Templates that should show for HAMILTON PORK location:');
    const hamiltonLocationId = 'fW45ffBBPar5EaNodDYq';
    
    const hamiltonTemplatesQuery = await db
      .collection('organizations').doc(orgId)
      .collection('checklist_templates')
      .where('locationIds', 'array-contains', hamiltonLocationId)
      .get();
    
    console.log(`   Found ${hamiltonTemplatesQuery.size} templates:`);
    hamiltonTemplatesQuery.forEach(doc => {
      const data = doc.data();
      console.log(`   ✅ ${data.name} (${doc.id})`);
    });

    // Test 3: Filter templates for Inn location only
    console.log('\n3️⃣ Templates that should show for INN location:');
    const innLocationId = '9uPGxodhJADOHTCS6Oqz';
    
    const innTemplatesQuery = await db
      .collection('organizations').doc(orgId)
      .collection('checklist_templates')
      .where('locationIds', 'array-contains', innLocationId)
      .get();
    
    console.log(`   Found ${innTemplatesQuery.size} templates:`);
    innTemplatesQuery.forEach(doc => {
      const data = doc.data();
      console.log(`   ✅ ${data.name} (${doc.id})`);
    });

    // Test 4: What happens if no location filter is applied (this might be the bug)
    console.log('\n4️⃣ ALL TEMPLATES (no location filter - this might be what your UI is showing):');
    const allTemplatesQuery = await db
      .collection('organizations').doc(orgId)
      .collection('checklist_templates')
      .get();
    
    console.log(`   Found ${allTemplatesQuery.size} templates:`);
    let chickiesInAll = 0;
    let hamiltonInAll = 0;
    let innInAll = 0;
    
    allTemplatesQuery.forEach(doc => {
      const data = doc.data();
      const name = data.name || 'NO NAME';
      const locationIds = data.locationIds || [];
      const locationNames = locationIds.map(id => locations[id]?.name || `Unknown(${id})`).join(', ');
      
      if (name.startsWith('C ')) chickiesInAll++;
      else if (name.startsWith('P ')) hamiltonInAll++;
      else if (name.startsWith('I ')) innInAll++;
      
      console.log(`   📋 ${name} → ${locationNames}`);
    });
    
    console.log(`\n📊 Summary of all templates:`);
    console.log(`   Chickies templates (C prefix): ${chickiesInAll}`);
    console.log(`   Hamilton templates (P prefix): ${hamiltonInAll}`);
    console.log(`   Inn templates (I prefix): ${innInAll}`);

    // Test 5: What if filtering by multiple locations (this might be happening)
    console.log('\n5️⃣ Templates when filtering by ALL locations (array-contains-any):');
    const allLocationIds = Object.keys(locations);
    
    const multiLocationQuery = await db
      .collection('organizations').doc(orgId)
      .collection('checklist_templates')
      .where('locationIds', 'array-contains-any', allLocationIds)
      .get();
    
    console.log(`   Found ${multiLocationQuery.size} templates (should be same as all templates):`);
    multiLocationQuery.forEach(doc => {
      const data = doc.data();
      console.log(`   📋 ${data.name}`);
    });

    // Analysis
    console.log('\n' + '='.repeat(60));
    console.log('🧐 ANALYSIS:');
    console.log('='.repeat(60));
    
    console.log('\n🎯 EXPECTED BEHAVIOR:');
    console.log('   When user selects Hamilton Pork location in your app,');
    console.log('   they should ONLY see the 16 "P" prefixed templates.');
    console.log('   They should NOT see any "C" (Chickies) or "I" (Inn) templates.');
    
    console.log('\n🐛 POSSIBLE BUG SCENARIOS:');
    console.log('   1. Location filter not being applied (showing all 48 templates)');
    console.log('   2. Multiple locations selected when only one should be');
    console.log('   3. Location context not properly passed to template queries');
    console.log('   4. User has permissions to see all locations instead of just one');

    console.log('\n🔧 TO FIX IN YOUR FLUTTER APP:');
    console.log('   1. Check location selection in shift_template_bottom_sheet.dart');
    console.log('   2. Ensure availableLocations only includes the current location');
    console.log('   3. Verify the query is using array-contains with single location ID');
    console.log('   4. Check user permissions and location restrictions');

  } catch (error) {
    console.error('❌ Analysis failed:', error);
  }
}

analyzeUIFilteringBehavior();