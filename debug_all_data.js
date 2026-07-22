// Debug script to check ALL checklists and templates in the system
const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: 'https://hands-app-staging-default-rtdb.firebaseio.com/'
  });
}

const db = admin.firestore();

async function debugAllData() {
  try {
    console.log('🔍 DEBUGGING ALL CHECKLISTS AND TEMPLATES');
    console.log('=====================================');
    
    // User details from the logs
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    const locationId = 'sYhcOTkX1VkeoPjtPuwZ';
    const userJobTypes = ['Kitchen Staff'];
    
    console.log(`Organization: ${orgId}`);
    console.log(`Location: ${locationId}`);
    console.log(`User Job Types: ${JSON.stringify(userJobTypes)}`);
    console.log('');
    
    // 1. Check ALL daily checklists for this location (any date)
    console.log('📋 CHECKING ALL DAILY CHECKLISTS...');
    const checklistsRef = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('daily_checklists');
    
    const allChecklistsSnapshot = await checklistsRef.get();
    
    console.log(`Found ${allChecklistsSnapshot.docs.length} total daily checklists`);
    
    for (const doc of allChecklistsSnapshot.docs) {
      const data = doc.data();
      console.log(`\n📋 CHECKLIST: ${doc.id}`);
      console.log(`  Template Name: ${data.templateName || 'Unknown'}`);
      console.log(`  Date: ${data.date || 'Unknown'}`);
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
    
    // 2. Check ALL shifts for this location
    console.log('\n\n🕐 CHECKING ALL SHIFTS...');
    
    const shiftsRef = db.collection('organizations')
      .doc(orgId)
      .collection('locations')
      .doc(locationId)
      .collection('shifts');
    
    const shiftsSnapshot = await shiftsRef.get();
    console.log(`Found ${shiftsSnapshot.docs.length} shifts`);
    
    for (const shiftDoc of shiftsSnapshot.docs) {
      const shiftData = shiftDoc.data();
      console.log(`\n🕐 SHIFT: ${shiftData.shiftName || shiftDoc.id}`);
      console.log(`  Shift ID: ${shiftDoc.id}`);
      console.log(`  Template IDs: ${JSON.stringify(shiftData.checklistTemplateIds || [])}`);
      console.log(`  Start Time: ${shiftData.startTime || 'Unknown'}`);
      console.log(`  End Time: ${shiftData.endTime || 'Unknown'}`);
    }
    
    // 3. Check ALL checklist templates for this organization
    console.log('\n\n📋 CHECKING ALL CHECKLIST TEMPLATES...');
    
    const templatesRef = db.collection('organizations')
      .doc(orgId)
      .collection('checklist_templates');
    
    const templatesSnapshot = await templatesRef.get();
    console.log(`Found ${templatesSnapshot.docs.length} checklist templates`);
    
    for (const templateDoc of templatesSnapshot.docs) {
      const templateData = templateDoc.data();
      console.log(`\n📋 TEMPLATE: ${templateDoc.id}`);
      console.log(`  Name: ${templateData.name || 'Unknown'}`);
      console.log(`  Job Types: ${JSON.stringify(templateData.jobTypes || templateData.jobType || 'none')}`);
      
      // Check if this template should be visible to kitchen staff
      const templateJobTypes = templateData.jobTypes || templateData.jobType;
      let shouldBeVisible = true;
      
      if (templateJobTypes) {
        const jobTypesList = Array.isArray(templateJobTypes) ? templateJobTypes : [templateJobTypes];
        const lowerJobTypes = jobTypesList.map(jt => jt.toString().toLowerCase().trim());
        const lowerUserJobTypes = userJobTypes.map(jt => jt.toLowerCase().trim());
        
        const intersection = lowerJobTypes.filter(jt => lowerUserJobTypes.includes(jt));
        shouldBeVisible = intersection.length > 0;
        
        console.log(`  Normalized Template Job Types: ${JSON.stringify(lowerJobTypes)}`);
        console.log(`  Normalized User Job Types: ${JSON.stringify(lowerUserJobTypes)}`);
        console.log(`  Intersection: ${JSON.stringify(intersection)}`);
      }
      
      console.log(`  Should be visible to Kitchen Staff: ${shouldBeVisible}`);
      
      if (!shouldBeVisible) {
        console.log(`  ❌ THIS TEMPLATE SHOULD BE FILTERED OUT!`);
      } else {
        console.log(`  ✅ This template should be visible`);
      }
    }
    
    console.log('\n🔍 DEBUG COMPLETE');
    console.log('=====================================');
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

debugAllData();