#!/usr/bin/env node
/**
 * Force create composite indexes for expiresAt field to ensure TTL visibility
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function forceIndexExpiresAt() {
  try {
    console.log('🔄 Force indexing expiresAt fields for TTL...\n');
    
    // Create a simple query on expiresAt to force index creation
    console.log('📝 Forcing tasks collection index...');
    try {
      const tasksQuery = await db.collectionGroup('tasks')
        .where('expiresAt', '>', new Date('2020-01-01'))
        .limit(1)
        .get();
      console.log(`✅ Tasks query successful - found ${tasksQuery.size} documents`);
    } catch (error) {
      console.log(`⚠️ Tasks query failed (this might trigger index creation): ${error.message}`);
    }
    
    console.log('\n📋 Forcing daily_checklists collection index...');
    try {
      const checklistsQuery = await db.collectionGroup('daily_checklists')
        .where('expiresAt', '>', new Date('2020-01-01'))
        .limit(1)
        .get();
      console.log(`✅ Daily checklists query successful - found ${checklistsQuery.size} documents`);
    } catch (error) {
      console.log(`⚠️ Daily checklists query failed (this might trigger index creation): ${error.message}`);
    }
    
    // Try ordering by expiresAt to force another type of index
    console.log('\n🔢 Forcing orderBy index on tasks...');
    try {
      const tasksOrderQuery = await db.collectionGroup('tasks')
        .orderBy('expiresAt')
        .limit(1)
        .get();
      console.log(`✅ Tasks orderBy query successful - found ${tasksOrderQuery.size} documents`);
    } catch (error) {
      console.log(`⚠️ Tasks orderBy query failed (this might trigger index creation): ${error.message}`);
    }
    
    console.log('\n🔢 Forcing orderBy index on daily_checklists...');
    try {
      const checklistsOrderQuery = await db.collectionGroup('daily_checklists')
        .orderBy('expiresAt')
        .limit(1)
        .get();
      console.log(`✅ Daily checklists orderBy query successful - found ${checklistsOrderQuery.size} documents`);
    } catch (error) {
      console.log(`⚠️ Daily checklists orderBy query failed (this might trigger index creation): ${error.message}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

forceIndexExpiresAt().then(() => {
  console.log('\n✨ Index forcing complete!');
  console.log('\n🎯 Next Steps:');
  console.log('1. Wait 10-15 minutes for Firebase to create indexes');
  console.log('2. Refresh the Firebase Console TTL page');
  console.log('3. Try creating the TTL policy again');
  console.log('\nIf expiresAt still doesn\'t appear, there might be a deeper issue with field detection.');
  
  process.exit(0);
});
