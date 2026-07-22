// Debug script to check the actual checklists and templates visible to kitchen staff user
const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://hands-app-staging-default-rtdb.firebaseio.com/'
  });
}

const db = admin.firestore();

async function debugActualChecklists() {
  try {
    console.log('🔍 DEBUGGING ACTUAL CHECKLISTS FOR KITCHEN STAFF USER');
    console.log('=====================================');
    
    // User details from the logs
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    const locationId = 'sYhcOTkX1VkeoPjtPuwZ';
    const userJobTypes = ['Kitchen Staff'];
    const todayString = '2025-09-21';
    
    console.log(`Organization: ${orgId}`);
    console.log(`Location: ${locationId}`);
    console.log(`User Job Types: ${JSON.stringify(userJobTypes)}`);
    console.log(`Date: ${todayString}`);
    console.log('');
    
    // 1. Check existing daily checklists
    console.log('📋 CHECKING EXISTING DAILY CHECKLISTS...');
    const checklistsRef = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists');
    
    const checklistSnapshot = await checklistsRef
      .where('date', '==', todayString)
      .get();
    
    console.log(`Found ${checklistSnapshot.docs.length} existing daily checklists`);
    
    for (const doc of checklistSnapshot.docs) {
      const data = doc.data();
      console.log(`\n📋 CHECKLIST: ${doc.id}`);
      console.log(`  Template Name: ${data.templateName || 'Unknown'}`);
      console.log(`  Shift ID: ${data.shiftId || 'Unknown'}`);
      console.log(`  Job Types: ${JSON.stringify(data.jobTypes || data.jobType || 'none')}`);
      console.log(`  Template ID: ${data.templateId || 'Unknown'}`);
      
      // Check if this should be visible to kitchen staff
      const checklistJobTypes = data.jobTypes || data.jobType;
      let shouldBeVisible = true;
      
      if (checklistJobTypes) {
        const jobTypesList = Array.isArray(checklistJobTypes) ? checklistJobTypes : [checklistJobTypes];
        const lowerJobTypes = jobTypesList.map(jt => jt.toString().toLowerCase().trim());
        const lowerUserJobTypes = userJobTypes.map(jt => jt.toLowerCase().trim());
        
        const intersection = lowerJobTypes.filter(jt => lowerUserJobTypes.includes(jt));
        shouldBeVisible = intersection.length > 0;
        
        console.log(`  Normalized Checklist Job Types: ${JSON.stringify(lowerJobTypes)}`);
        console.log(`  Normalized User Job Types: ${JSON.stringify(lowerUserJobTypes)}`);
        console.log(`  Intersection: ${JSON.stringify(intersection)}`);
      }
      
      console.log(`  Should be visible to Kitchen Staff: ${shouldBeVisible}`);
      
      if (!shouldBeVisible) {
        console.log(`  ❌ THIS CHECKLIST SHOULD BE FILTERED OUT!`);
      } else {
        console.log(`  ✅ This checklist should be visible`);
      }
    }
    
    // 2. Check the checklist templates for the shifts
    console.log('\n\n🎯 CHECKING CHECKLIST TEMPLATES...');
    
    // Get shift data to find template IDs
    const shiftsRef = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('shifts');
    
    const shiftsSnapshot = await shiftsRef.get();
    
    for (const shiftDoc of shiftsSnapshot.docs) {
      const shiftData = shiftDoc.data();
      console.log(`\n🕐 SHIFT: ${shiftData.shiftName || shiftDoc.id}`);
      console.log(`  Shift ID: ${shiftDoc.id}`);
      console.log(`  Template IDs: ${JSON.stringify(shiftData.checklistTemplateIds || [])}`);
      
      if (shiftData.checklistTemplateIds) {
        for (const templateId of shiftData.checklistTemplateIds) {
          console.log(`\n  📋 TEMPLATE: ${templateId}`);
          
          try {
            const templateDoc = await db.collection('organizations')
              .doc(orgId)
              .collection('checklist_templates')
              .doc(templateId)
              .get();
            
            if (templateDoc.exists) {
              const templateData = templateDoc.data();
              console.log(`    Name: ${templateData.name || 'Unknown'}`);
              console.log(`    Job Types: ${JSON.stringify(templateData.jobTypes || templateData.jobType || 'none')}`);
              
              // Check if this template should be visible to kitchen staff
              const templateJobTypes = templateData.jobTypes || templateData.jobType;
              let shouldBeVisible = true;
              
              if (templateJobTypes) {
                const jobTypesList = Array.isArray(templateJobTypes) ? templateJobTypes : [templateJobTypes];
                const lowerJobTypes = jobTypesList.map(jt => jt.toString().toLowerCase().trim());
                const lowerUserJobTypes = userJobTypes.map(jt => jt.toLowerCase().trim());
                
                const intersection = lowerJobTypes.filter(jt => lowerUserJobTypes.includes(jt));
                shouldBeVisible = intersection.length > 0;
                
                console.log(`    Normalized Template Job Types: ${JSON.stringify(lowerJobTypes)}`);
                console.log(`    Normalized User Job Types: ${JSON.stringify(lowerUserJobTypes)}`);
                console.log(`    Intersection: ${JSON.stringify(intersection)}`);
              }
              
              console.log(`    Should be visible to Kitchen Staff: ${shouldBeVisible}`);
              
              if (!shouldBeVisible) {
                console.log(`    ❌ THIS TEMPLATE SHOULD BE FILTERED OUT!`);
              } else {
                console.log(`    ✅ This template should be visible`);
              }
            } else {
              console.log(`    ❌ Template not found!`);
            }
          } catch (error) {
            console.log(`    ❌ Error fetching template: ${error.message}`);
          }
        }
      }
    }
    
    console.log('\n🔍 DEBUG COMPLETE');
    console.log('=====================================');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

debugActualChecklists();