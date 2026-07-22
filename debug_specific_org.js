const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function checkCurrentUser() {
  try {
    console.log('🔍 Checking specific organization data...\n');
    
    // Check for users with specific organization ID (from your fix script)
    const userQuery = await db.collection('users').where('organizationId', '==', 'vnE0olvi1Tswjtdb19MI').get();
    console.log(`Users in org vnE0olvi1Tswjtdb19MI: ${userQuery.size}`);
    
    userQuery.forEach(doc => {
      const data = doc.data();
      console.log(`User: ${data.firstName || 'N/A'} ${data.lastName || 'N/A'}`);
      console.log(`  Email: ${data.email || data.emailAddress || 'N/A'}`);
      console.log(`  Role: ${data.userRole || 'N/A'}`);
      console.log(`  JobTypes: ${JSON.stringify(data.jobTypes || data.jobType || 'NONE')}`);
      console.log(`  LocationId: ${data.locationId || 'N/A'}`);
      console.log('---');
    });
    
    // Check this specific organization
    const orgDoc = await db.collection('organizations').doc('vnE0olvi1Tswjtdb19MI').get();
    if (orgDoc.exists) {
      console.log('\n🏢 Organization data:');
      const orgData = orgDoc.data();
      console.log(`  Name: ${orgData.name || 'N/A'}`);
      console.log(`  Created: ${orgData.createdAt ? orgData.createdAt.toDate() : 'N/A'}`);
      
      const locationsSnapshot = await db.collection('organizations').doc('vnE0olvi1Tswjtdb19MI').collection('locations').get();
      console.log(`\n📍 Locations in this org: ${locationsSnapshot.size}`);
      
      for (const locDoc of locationsSnapshot.docs) {
        const locData = locDoc.data();
        console.log(`\nLocation: ${locDoc.id}`);
        console.log(`  Name: ${locData.name || 'N/A'}`);
        console.log(`  Address: ${locData.address || 'N/A'}`);
        
        const shiftsSnapshot = await db.collection('organizations').doc('vnE0olvi1Tswjtdb19MI')
          .collection('locations').doc(locDoc.id).collection('shifts').get();
        console.log(`  Shifts: ${shiftsSnapshot.size}`);
        
        shiftsSnapshot.forEach(shiftDoc => {
          const shiftData = shiftDoc.data();
          console.log(`    - ${shiftData.shiftName || shiftDoc.id}`);
          console.log(`      JobType: ${JSON.stringify(shiftData.jobType || 'N/A')}`);
          console.log(`      Time: ${shiftData.startTime || 'N/A'} - ${shiftData.endTime || 'N/A'}`);
        });
        
        // Check for checklist templates
        const templatesSnapshot = await db.collection('organizations').doc('vnE0olvi1Tswjtdb19MI')
          .collection('locations').doc(locDoc.id).collection('checklistTemplates').get();
        console.log(`  Checklist Templates: ${templatesSnapshot.size}`);
        
        templatesSnapshot.forEach(templateDoc => {
          const templateData = templateDoc.data();
          console.log(`    - ${templateData.name || templateDoc.id}`);
          console.log(`      JobTypes: ${JSON.stringify(templateData.jobTypes || templateData.jobType || 'N/A')}`);
        });
      }
      
      // Check organization-level templates
      const orgTemplatesSnapshot = await db.collection('organizations').doc('vnE0olvi1Tswjtdb19MI').collection('checklistTemplates').get();
      console.log(`\n📋 Organization-level templates: ${orgTemplatesSnapshot.size}`);
      
      orgTemplatesSnapshot.forEach(templateDoc => {
        const templateData = templateDoc.data();
        console.log(`  - ${templateData.name || templateDoc.id}`);
        console.log(`    JobTypes: ${JSON.stringify(templateData.jobTypes || templateData.jobType || 'N/A')}`);
      });
      
    } else {
      console.log('❌ Organization vnE0olvi1Tswjtdb19MI not found');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkCurrentUser().then(() => {
  console.log('\n✅ Check complete');
  process.exit(0);
});