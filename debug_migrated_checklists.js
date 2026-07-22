const { Firestore } = require('@google-cloud/firestore');

// Use the planwithhands database
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function debugMigratedChecklists() {
  try {
    console.log('🔍 Investigating migrated checklists issue...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const chickiesLocationId = 'abTp8sjidL5QVirAewe6';
    const porkLocationId = 'fW45ffBBPar5EaNodDYq';
    const shiftId = 'JLo4mc11PpjK9HOdRcdV';
    const date = '2025-09-29';
    
    console.log('1. Checking ALL daily checklists for today at Chickies (including potentially corrupted ones)...\n');
    
    // Get ALL daily checklists for today at Chickies, regardless of shiftId
    const allChickiesQuery = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(chickiesLocationId)
      .collection('daily_checklists')
      .where('date', '==', date);
    
    const allChickiesSnapshot = await allChickiesQuery.get();
    
    console.log(`Found ${allChickiesSnapshot.size} total daily checklists for today at Chickies:`);
    
    allChickiesSnapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n${index + 1}. ${data.templateName || 'MISSING_NAME'}`);
      console.log(`   Document ID: ${doc.id}`);
      console.log(`   Template ID: ${data.templateId || 'MISSING'}`);
      console.log(`   Shift ID: ${data.shiftId || 'MISSING'}`);
      console.log(`   Date: ${data.date || 'MISSING'}`);
      console.log(`   Location ID: ${data.locationId || 'MISSING'}`);
      console.log(`   Organization ID: ${data.organizationId || 'MISSING'}`);
      console.log(`   Job Types: ${JSON.stringify(data.jobTypes || [])}`);
      console.log(`   Created: ${data.createdAt || 'MISSING'}`);
      
      // Check if this matches the Pre Dinner shift
      const isPreDinner = data.shiftId === shiftId;
      console.log(`   ✅ Matches Pre Dinner shift: ${isPreDinner}`);
      
      // Check for potential issues
      const issues = [];
      if (!data.templateId) issues.push('Missing templateId');
      if (!data.shiftId) issues.push('Missing shiftId');
      if (data.shiftId !== shiftId) issues.push('Wrong shiftId');
      if (!data.locationId) issues.push('Missing locationId');
      if (data.locationId !== chickiesLocationId) issues.push('Wrong locationId');
      if (!data.organizationId) issues.push('Missing organizationId');
      
      if (issues.length > 0) {
        console.log(`   ⚠️  ISSUES: ${issues.join(', ')}`);
      }
    });
    
    console.log('\n2. Looking for the specific missing checklists (C Bar and C Server)...\n');
    
    const expectedNames = ['C Bar - Pre Dinner', 'C Server - Pre Dinner'];
    const foundMissing = [];
    
    for (const expectedName of expectedNames) {
      const found = allChickiesSnapshot.docs.find(doc => 
        doc.data().templateName === expectedName
      );
      
      if (found) {
        console.log(`✅ Found "${expectedName}"`);
        const data = found.data();
        
        // Check if it has the right shift ID
        if (data.shiftId !== shiftId) {
          console.log(`   ⚠️  PROBLEM: Wrong shift ID! Has "${data.shiftId}", should be "${shiftId}"`);
          foundMissing.push({ doc: found, issue: 'wrong_shift_id' });
        } else {
          console.log(`   ✅ Correct shift ID`);
        }
      } else {
        console.log(`❌ Missing "${expectedName}"`);
        
        // Search for it with partial name matching
        const partialMatch = allChickiesSnapshot.docs.find(doc => {
          const name = doc.data().templateName || '';
          return name.toLowerCase().includes('bar') || name.toLowerCase().includes('server');
        });
        
        if (partialMatch) {
          console.log(`   🔍 Found potential match: "${partialMatch.data().templateName}"`);
        }
      }
    }
    
    console.log('\n3. Checking if they exist at Hamilton Pork (to verify migration)...\n');
    
    const porkQuery = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(porkLocationId)
      .collection('daily_checklists')
      .where('date', '==', date);
    
    const porkSnapshot = await porkQuery.get();
    
    const porkChecklists = porkSnapshot.docs.filter(doc => {
      const name = doc.data().templateName || '';
      return name.includes('C Bar') || name.includes('C Server');
    });
    
    if (porkChecklists.length > 0) {
      console.log(`❌ Found ${porkChecklists.length} Chickies checklists still at Hamilton Pork!`);
      porkChecklists.forEach((doc, index) => {
        console.log(`   ${index + 1}. ${doc.data().templateName}`);
      });
      console.log('   Migration may not have completed properly.');
    } else {
      console.log('✅ No Chickies checklists found at Hamilton Pork - migration was successful');
    }
    
    console.log('\n4. Fixing any issues found...\n');
    
    if (foundMissing.length > 0) {
      console.log(`Found ${foundMissing.length} checklists that need fixing...`);
      
      const batch = db.batch();
      
      for (const item of foundMissing) {
        if (item.issue === 'wrong_shift_id') {
          console.log(`Fixing shift ID for "${item.doc.data().templateName}"`);
          
          batch.update(item.doc.ref, {
            shiftId: shiftId,
            updatedAt: new Date()
          });
        }
      }
      
      await batch.commit();
      console.log('✅ Fixed shift ID issues!');
      
      console.log('\n🎉 Try refreshing the app now - the missing checklists should appear!');
    } else {
      console.log('No fixable issues found. The problem might be elsewhere.');
    }
    
  } catch (error) {
    console.error('Error debugging migrated checklists:', error);
  }
}

debugMigratedChecklists();