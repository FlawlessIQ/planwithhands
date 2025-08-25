#!/usr/bin/env node
/**
 * Verify the expiresAt field format and structure
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function verifyExpiresAtFields() {
  try {
    console.log('🔍 Verifying expiresAt field structure...\n');
    
    // Check daily_checklists
    console.log('📋 DAILY_CHECKLISTS:');
    const checklistQuery = db.collectionGroup('daily_checklists').limit(3);
    const checklistSnapshot = await checklistQuery.get();
    
    for (const doc of checklistSnapshot.docs) {
      const data = doc.data();
      console.log(`  Document: ${doc.id}`);
      console.log(`  Path: ${doc.ref.path}`);
      
      if (data.expiresAt) {
        console.log(`  ✅ expiresAt: ${data.expiresAt.toDate().toISOString()}`);
        console.log(`  📅 Type: ${typeof data.expiresAt}, Constructor: ${data.expiresAt.constructor.name}`);
        console.log(`  🔢 Seconds: ${data.expiresAt.seconds}, Nanoseconds: ${data.expiresAt.nanoseconds}`);
      } else {
        console.log(`  ❌ No expiresAt field`);
      }
      console.log();
    }
    
    // Check tasks  
    console.log('\n📝 TASKS:');
    const tasksQuery = db.collectionGroup('tasks').where('expiresAt', '!=', null).limit(3);
    const tasksSnapshot = await tasksQuery.get();
    
    for (const doc of tasksSnapshot.docs) {
      const data = doc.data();
      console.log(`  Document: ${doc.id}`);
      console.log(`  Path: ${doc.ref.path}`);
      
      if (data.expiresAt) {
        console.log(`  ✅ expiresAt: ${data.expiresAt.toDate().toISOString()}`);
        console.log(`  📅 Type: ${typeof data.expiresAt}, Constructor: ${data.expiresAt.constructor.name}`);
        console.log(`  🔢 Seconds: ${data.expiresAt.seconds}, Nanoseconds: ${data.expiresAt.nanoseconds}`);
      } else {
        console.log(`  ❌ No expiresAt field`);
      }
      console.log();
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyExpiresAtFields().then(() => {
  console.log('✨ Verification complete!');
  console.log('\n🎯 Firebase Console TTL Setup:');
  console.log('1. Go to: https://console.firebase.google.com/project/plan-with-hands/firestore/usage');
  console.log('2. Click "Create TTL policy"');
  console.log('3. Collection group: daily_checklists');
  console.log('4. Field name: expiresAt');
  console.log('5. Repeat for "tasks" collection group');
  
  process.exit(0);
});
