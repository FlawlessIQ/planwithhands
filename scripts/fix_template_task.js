#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();
// Connect to the planwithhands database
db.settings({
  databaseId: 'planwithhands'
});

async function fixTemplateTask() {
  try {
    const orgId = 'vnE0olvi1Tswjtdb19MI';
    const templateId = 'vBhZgbusSlyJMX2el1xc'; // Kitchen opening list
    const templateTaskId = '8684736526bf4e76'; // check fridge temps
    
    console.log('🔧 Fixing template task photoRequired field...\n');
    console.log(`📍 Organization: ${orgId}`);
    console.log(`📋 Template: ${templateId}`);
    console.log(`📝 Task: ${templateTaskId}`);
    
    // Get current template task
    const templateTaskRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('checklist_templates')
      .doc(templateId)
      .collection('tasks')
      .doc(templateTaskId);
    
    const templateTaskDoc = await templateTaskRef.get();
    
    if (!templateTaskDoc.exists) {
      console.log('❌ Template task not found!');
      return;
    }
    
    const currentData = templateTaskDoc.data();
    console.log('\n📋 Current template task data:');
    console.log(`   Task name: ${currentData.name}`);
    console.log(`   photoRequired: ${currentData.photoRequired}`);
    
    // Update photoRequired to true
    await templateTaskRef.update({
      photoRequired: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('\n✅ Updated template task:');
    console.log(`   photoRequired: true`);
    
    // Verify the update
    const updatedDoc = await templateTaskRef.get();
    const updatedData = updatedDoc.data();
    console.log('\n🔍 Verification:');
    console.log(`   Task name: ${updatedData.name}`);
    console.log(`   photoRequired: ${updatedData.photoRequired}`);
    
    if (updatedData.photoRequired === true) {
      console.log('\n🎉 SUCCESS: Template task now has photoRequired: true');
      
      console.log('\n⚠️  Note: Existing daily tasks will still have photoRequired: false');
      console.log('   New daily checklists generated from this template will have photoRequired: true');
      console.log('   The filtering logic will now use the template fallback for old tasks');
    } else {
      console.log('\n❌ ERROR: Update failed');
    }
    
  } catch (error) {
    console.error(`❌ Error fixing template task:`, error);
  }
}

fixTemplateTask()
  .then(() => {
    console.log(`\n🎉 Template fix completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Fix failed:`, error);
    process.exit(1);
  });
