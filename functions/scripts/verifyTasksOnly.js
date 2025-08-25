#!/usr/bin/env node
/**
 * Simple verification of tasks expiresAt field
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function verifyTasksExpiresAt() {
  try {
    console.log('📝 TASKS Collection Verification:\n');
    
    // Get specific tasks that we know have expiresAt
    const tasksQuery = db.collectionGroup('tasks').limit(5);
    const tasksSnapshot = await tasksQuery.get();
    
    let foundWithExpiresAt = 0;
    
    for (const doc of tasksSnapshot.docs) {
      const data = doc.data();
      
      if (data.expiresAt) {
        foundWithExpiresAt++;
        console.log(`✅ Document: ${doc.id}`);
        console.log(`  Path: ${doc.ref.path}`);
        console.log(`  expiresAt: ${data.expiresAt.toDate().toISOString()}`);
        console.log(`  Type: ${typeof data.expiresAt}, Constructor: ${data.expiresAt.constructor.name}`);
        console.log(`  Seconds: ${data.expiresAt.seconds}, Nanoseconds: ${data.expiresAt.nanoseconds}\n`);
      }
    }
    
    console.log(`📊 Found ${foundWithExpiresAt} tasks with expiresAt fields out of ${tasksSnapshot.size} total tasks`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyTasksExpiresAt().then(() => {
  console.log('\n✨ Tasks verification complete!');
  process.exit(0);
});
