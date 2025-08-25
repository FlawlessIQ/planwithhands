#!/usr/bin/env node
/**
 * Find all tasks collections using collectionGroup query
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function findTasks() {
  try {
    console.log('🔍 Finding all tasks using collectionGroup query...\n');
    
    // Query all tasks using collectionGroup
    const tasksQuery = db.collectionGroup('tasks').limit(10);
    const snapshot = await tasksQuery.get();
    
    console.log(`Found ${snapshot.size} task documents:`);
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const hasExpiresAt = data.expiresAt ? '🔥' : '  ';
      console.log(`${hasExpiresAt} ${doc.ref.path}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

findTasks().then(() => {
  console.log('✨ Done finding tasks');
  process.exit(0);
});
