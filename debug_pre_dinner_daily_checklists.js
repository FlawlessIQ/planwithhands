const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://plan-with-hands-default-rtdb.firebaseio.com'
  });
}

const db = admin.firestore();

async function debugPreDinnerDailyChecklists() {
  try {
    console.log('🔍 Debugging Chickies Pre Dinner daily checklists for 2025-09-29...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const locationId = 'abTp8sjidL5QVirAewe6';
    const shiftId = 'JLo4mc11PpjK9HOdRcdV';
    const date = '2025-09-29';
    
    // Query daily checklists for Pre Dinner shift today
    const dailyChecklistsQuery = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists')
      .where('date', '==', date)
      .where('shiftId', '==', shiftId);
    
    const dailyChecklistsSnapshot = await dailyChecklistsQuery.get();
    
    console.log(`📊 SUMMARY:`);
    console.log(`- Total daily checklists found: ${dailyChecklistsSnapshot.size}`);
    console.log(`- Expected: 4 (C Bar, C Server, C Busser, C Manager)`);
    console.log(`- Missing: ${4 - dailyChecklistsSnapshot.size}\n`);
    
    if (dailyChecklistsSnapshot.empty) {
      console.log('❌ No daily checklists found for Pre Dinner shift today!');
      console.log('This explains why only templates show in admin but no actual daily instances.');
      return;
    }
    
    console.log('📋 DAILY CHECKLISTS FOUND:');
    dailyChecklistsSnapshot.forEach((doc, index) => {
      const data = doc.data();
      console.log(`\n${index + 1}. Document ID: ${doc.id}`);
      console.log(`   Template ID: ${data.templateId || 'N/A'}`);
      console.log(`   Template Name: ${data.templateName || 'N/A'}`);
      console.log(`   Date: ${data.date}`);
      console.log(`   Shift ID: ${data.shiftId}`);
      console.log(`   Organization: ${data.organizationId}`);
      console.log(`   Location: ${data.locationId}`);
      console.log(`   Created: ${data.createdAt?.toDate() || 'N/A'}`);
    });
    
    console.log('\n🔍 CHECKING TEMPLATE ASSIGNMENTS...');
    
    // Get all templates assigned to Pre Dinner shift
    const shiftDoc = await db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('shifts')
      .doc(shiftId)
      .get();
    
    if (shiftDoc.exists) {
      const shiftData = shiftDoc.data();
      const assignedTemplates = shiftData.assignedTemplates || [];
      
      console.log(`\n📝 TEMPLATES ASSIGNED TO PRE DINNER SHIFT: ${assignedTemplates.length}`);
      
      for (const templateId of assignedTemplates) {
        const templateDoc = await db.collection('organizations')
          .doc(orgId)
          .collection('locations')
          .doc(locationId)
          .collection('templates')
          .doc(templateId)
          .get();
        
        if (templateDoc.exists) {
          const templateData = templateDoc.data();
          const hasDaily = dailyChecklistsSnapshot.docs.some(doc => 
            doc.data().templateId === templateId
          );
          
          console.log(`\n   Template: ${templateData.name}`);
          console.log(`   ID: ${templateId}`);
          console.log(`   Job Types: ${JSON.stringify(templateData.jobTypes || [])}`);
          console.log(`   Daily checklist exists: ${hasDaily ? '✅' : '❌'}`);
          
          if (!hasDaily) {
            console.log(`   ⚠️  MISSING DAILY CHECKLIST FOR THIS TEMPLATE!`);
          }
        }
      }
    }
    
    console.log('\n🔍 CHECKING IF DAILY CHECKLISTS ARE IN WRONG LOCATION...');
    
    // Check if daily checklists exist but in wrong location
    const allDailyChecklistsQuery = db.collectionGroup('daily_checklists')
      .where('organizationId', '==', orgId)
      .where('date', '==', date)
      .where('shiftId', '==', shiftId);
    
    const allDailyChecklistsSnapshot = await allDailyChecklistsQuery.get();
    
    console.log(`\n🌐 ORGANIZATION-WIDE SEARCH FOR PRE DINNER CHECKLISTS:`);
    console.log(`   Found ${allDailyChecklistsSnapshot.size} checklists across all locations`);
    
    allDailyChecklistsSnapshot.forEach((doc, index) => {
      const data = doc.data();
      const docLocationId = data.locationId;
      const isCorrectLocation = docLocationId === locationId;
      
      console.log(`\n   ${index + 1}. ${data.templateName || 'Unknown'}`);
      console.log(`      Location ID: ${docLocationId}`);
      console.log(`      Correct location: ${isCorrectLocation ? '✅' : '❌'}`);
      console.log(`      Path: ${doc.ref.path}`);
      
      if (!isCorrectLocation) {
        console.log(`      ⚠️  THIS CHECKLIST IS IN THE WRONG LOCATION!`);
      }
    });
    
  } catch (error) {
    console.error('Error debugging Pre Dinner daily checklists:', error);
  }
}

debugPreDinnerDailyChecklists();