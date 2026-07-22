const admin = require('firebase-admin');

// Initialize admin SDK if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function debugOrganizationData() {
  console.log('🏢 Debugging Organization and Location Data...\n');

  try {
    // 1. Check Organizations
    console.log('🏢 === ORGANIZATIONS ===');
    const orgsSnapshot = await db.collection('organizations').get();
    
    if (!orgsSnapshot.empty) {
      for (const doc of orgsSnapshot.docs) {
        const data = doc.data();
        console.log(`Organization ID: ${doc.id}`);
        console.log(`  Name: ${data.name || 'N/A'}`);
        console.log(`  Created: ${data.createdAt ? data.createdAt.toDate() : 'N/A'}`);
        
        // Check locations under this org
        const locationsSnapshot = await db.collection('organizations').doc(doc.id).collection('locations').get();
        console.log(`  Locations: ${locationsSnapshot.size}`);
        
        locationsSnapshot.forEach(locDoc => {
          const locData = locDoc.data();
          console.log(`    - ${locDoc.id}: ${locData.name || 'N/A'}`);
        });
        
        // Check shifts under each location
        for (const locDoc of locationsSnapshot.docs) {
          const shiftsSnapshot = await db.collection('organizations').doc(doc.id)
            .collection('locations').doc(locDoc.id)
            .collection('shifts').get();
          
          if (shiftsSnapshot.size > 0) {
            console.log(`    Shifts in ${locDoc.id}: ${shiftsSnapshot.size}`);
            shiftsSnapshot.forEach(shiftDoc => {
              const shiftData = shiftDoc.data();
              console.log(`      - ${shiftData.shiftName || shiftDoc.id}: ${JSON.stringify(shiftData.jobType || 'No jobType')}`);
            });
          }
        }
        
        // Check checklist templates under this org
        const templatesSnapshot = await db.collection('organizations').doc(doc.id).collection('checklistTemplates').get();
        console.log(`  Checklist Templates: ${templatesSnapshot.size}`);
        
        templatesSnapshot.forEach(templateDoc => {
          const templateData = templateDoc.data();
          console.log(`    - ${templateData.name || templateDoc.id}: ${JSON.stringify(templateData.jobTypes || templateData.jobType || 'No jobType')}`);
        });
        
        console.log('---');
      }
    } else {
      console.log('❌ No organizations found');
    }

    // 2. Check if there are global templates
    console.log('\n📋 === GLOBAL CHECKLIST TEMPLATES ===');
    const globalTemplatesSnapshot = await db.collection('checklistTemplates').get();
    console.log(`Found ${globalTemplatesSnapshot.size} global templates`);
    
    globalTemplatesSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`Template: ${data.name || doc.id}`);
      console.log(`  JobTypes: ${JSON.stringify(data.jobTypes || data.jobType || 'No jobType')}`);
    });

  } catch (error) {
    console.error('❌ Error debugging organization data:', error);
  }
}

// Run the debug
debugOrganizationData().then(() => {
  console.log('\n✅ Debug complete');
  process.exit(0);
}).catch(console.error);