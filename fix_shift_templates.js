const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');
const orgId = '3qjYzHagWmfbnMieJ1aj';

async function fixShiftTemplateReferences() {
  console.log('🔧 FIXING SHIFT TEMPLATE REFERENCES');
  console.log(`Organization: ${orgId}`);
  console.log('=' .repeat(80));
  
  try {
    // 1. Get all existing templates
    console.log('1️⃣ FINDING EXISTING TEMPLATES:');
    const templatesSnapshot = await db.collection('organizations').doc(orgId)
      .collection('checklist_templates').get();
    
    console.log(`Found ${templatesSnapshot.size} existing templates:`);
    const existingTemplates = [];
    
    templatesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      existingTemplates.push({
        id: doc.id,
        name: data.name || 'Unnamed',
        isActive: data.isActive
      });
      console.log(`  ✅ ${doc.id}: "${data.name}" (Active: ${data.isActive})`);
    });
    
    // 2. Check current shift configuration
    console.log('\n2️⃣ CURRENT SHIFT CONFIGURATION:');
    const dinnerShiftId = 'CioNb2WRnPiRLM6wRH8p'; // From your screenshot
    const shiftRef = db.collection('organizations').doc(orgId)
      .collection('shifts').doc(dinnerShiftId);
    
    const shiftSnap = await shiftRef.get();
    if (!shiftSnap.exists) {
      console.log('❌ Dinner shift not found');
      return;
    }
    
    const shiftData = shiftSnap.data();
    const currentTemplateIds = shiftData.checklistTemplateIds || [];
    
    console.log(`Dinner shift current config:`);
    console.log(`  Name: ${shiftData.shiftName || shiftData.name}`);
    console.log(`  Current template IDs: ${JSON.stringify(currentTemplateIds)}`);
    
    // Check which template IDs are invalid
    const validTemplateIds = [];
    const invalidTemplateIds = [];
    
    for (const templateId of currentTemplateIds) {
      const exists = existingTemplates.some(t => t.id === templateId);
      if (exists) {
        validTemplateIds.push(templateId);
      } else {
        invalidTemplateIds.push(templateId);
      }
    }
    
    console.log(`  ✅ Valid template IDs: ${JSON.stringify(validTemplateIds)}`);
    console.log(`  ❌ Invalid template IDs: ${JSON.stringify(invalidTemplateIds)}`);
    
    // 3. Propose solution
    console.log('\n3️⃣ SOLUTION OPTIONS:');
    
    if (invalidTemplateIds.length > 0) {
      console.log('OPTION 1: Remove invalid template IDs from shift');
      console.log(`  Update shift to use only: ${JSON.stringify(validTemplateIds)}`);
      
      console.log('\nOPTION 2: Use existing active templates');
      const activeTemplates = existingTemplates.filter(t => t.isActive);
      const activeTemplateIds = activeTemplates.map(t => t.id);
      console.log(`  Update shift to use: ${JSON.stringify(activeTemplateIds)}`);
      console.log('  Templates:');
      activeTemplates.forEach(t => {
        console.log(`    - ${t.id}: "${t.name}"`);
      });
      
      // 4. Execute fix
      console.log('\n4️⃣ EXECUTING FIX:');
      console.log('Updating shift to use only existing active templates...');
      
      const updateData = {
        checklistTemplateIds: activeTemplateIds,
        updatedAt: admin.firestore.Timestamp.now(),
        updatedBy: 'fix-script'
      };
      
      await shiftRef.update(updateData);
      console.log('✅ Shift updated successfully!');
      
      console.log('\n📋 NEW SHIFT CONFIGURATION:');
      console.log(`  Template IDs: ${JSON.stringify(activeTemplateIds)}`);
      console.log('  Templates:');
      activeTemplates.forEach(t => {
        console.log(`    - "${t.name}" (${t.id})`);
      });
      
      // 5. Clean up today's invalid checklists
      console.log('\n5️⃣ CLEANING UP TODAY\'S INVALID CHECKLISTS:');
      const today = '2025-10-02';
      
      const locationsSnapshot = await db.collection('organizations').doc(orgId)
        .collection('locations').get();
      
      let deletedCount = 0;
      
      for (const locDoc of locationsSnapshot.docs) {
        const locationId = locDoc.id;
        
        const todayChecklists = await db.collection('organizations').doc(orgId)
          .collection('locations').doc(locationId)
          .collection('daily_checklists')
          .where('date', '==', today)
          .get();
        
        for (const checklistDoc of todayChecklists.docs) {
          const checklistData = checklistDoc.data();
          const templateIds = checklistData.checklistTemplateIds || [];
          
          // Check if this checklist has any invalid template IDs
          const hasInvalidTemplates = templateIds.some(tid => invalidTemplateIds.includes(tid));
          
          if (hasInvalidTemplates) {
            console.log(`  🗑️  Deleting invalid checklist: ${checklistDoc.id}`);
            console.log(`    Location: ${locationId}`);
            console.log(`    Invalid templates: ${JSON.stringify(templateIds.filter(tid => invalidTemplateIds.includes(tid)))}`);
            
            // Delete the checklist and all its tasks
            const batch = db.batch();
            
            // Delete all tasks first
            const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
            tasksSnapshot.docs.forEach(taskDoc => {
              batch.delete(taskDoc.ref);
            });
            
            // Delete the checklist
            batch.delete(checklistDoc.ref);
            
            await batch.commit();
            deletedCount++;
          }
        }
      }
      
      console.log(`✅ Deleted ${deletedCount} invalid checklists`);
      
      console.log('\n🎉 FIX COMPLETE!');
      console.log('The daily generator will now only create checklists for valid templates.');
      console.log('No more "Unknown Template" checklists should be generated.');
      
    } else {
      console.log('✅ All template IDs in shift are valid');
      console.log('The issue might be elsewhere in the system');
    }
    
  } catch (error) {
    console.error('❌ Error fixing shift template references:', error);
  }
  
  process.exit(0);
}

fixShiftTemplateReferences();