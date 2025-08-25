#!/usr/bin/env node
/**
 * Add expiresAt field to template tasks to ensure TTL field consistency
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function addExpiresAtToTemplateTasks() {
  try {
    console.log('🔄 Adding expiresAt to template tasks...\n');
    
    // Set expiration date very far in future for templates (they shouldn't expire)
    const farFutureDate = admin.firestore.Timestamp.fromDate(new Date('2099-12-31'));
    
    // Find all template tasks (those without expiresAt)
    const tasksQuery = db.collectionGroup('tasks');
    const tasksSnapshot = await tasksQuery.get();
    
    const batch = db.batch();
    let templateTasksUpdated = 0;
    
    for (const doc of tasksSnapshot.docs) {
      const data = doc.data();
      
      // If this task doesn't have expiresAt, it's likely a template task
      if (!data.expiresAt) {
        console.log(`📋 Adding expiresAt to template task: ${doc.ref.path}`);
        batch.update(doc.ref, {
          expiresAt: farFutureDate
        });
        templateTasksUpdated++;
      }
    }
    
    if (templateTasksUpdated > 0) {
      await batch.commit();
      console.log(`✅ Updated ${templateTasksUpdated} template tasks with expiresAt field`);
    } else {
      console.log('✅ All tasks already have expiresAt field');
    }
    
    // Verify the update
    console.log('\n🔍 Verifying all tasks now have expiresAt...');
    const verifyQuery = db.collectionGroup('tasks');
    const verifySnapshot = await verifyQuery.get();
    
    let withExpiresAt = 0;
    let withoutExpiresAt = 0;
    
    for (const doc of verifySnapshot.docs) {
      const data = doc.data();
      if (data.expiresAt) {
        withExpiresAt++;
      } else {
        withoutExpiresAt++;
      }
    }
    
    console.log(`📊 Results:`);
    console.log(`   ✅ Tasks with expiresAt: ${withExpiresAt}`);
    console.log(`   ❌ Tasks without expiresAt: ${withoutExpiresAt}`);
    
    if (withoutExpiresAt === 0) {
      console.log('\n🎉 SUCCESS! All tasks now have expiresAt field');
      console.log('🎯 Firebase Console should now detect expiresAt as available field');
    } else {
      console.log('\n⚠️  Some tasks still missing expiresAt field');
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

addExpiresAtToTemplateTasks().then(() => {
  console.log('\n✨ Template task update complete!');
  console.log('\n🎯 Next Steps:');
  console.log('1. Wait 5-10 minutes for Firebase indexing');
  console.log('2. Refresh the Firebase Console TTL page');
  console.log('3. The expiresAt field should now appear in the dropdown');
  console.log('\nNote: Template tasks are set to expire in 2099 (effectively never)');
  
  process.exit(0);
});
