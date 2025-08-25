#!/usr/bin/env node
/**
 * Check the exact structure and paths of tasks with expiresAt
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function debugTasksPaths() {
  try {
    console.log('🔍 Debugging tasks collection structure...\n');
    
    // Get all task documents with their full paths
    const tasksQuery = db.collectionGroup('tasks').limit(10);
    const tasksSnapshot = await tasksQuery.get();
    
    console.log(`📊 Found ${tasksSnapshot.size} task documents:\n`);
    
    for (const doc of tasksSnapshot.docs) {
      const data = doc.data();
      console.log(`📝 Document ID: ${doc.id}`);
      console.log(`   Path: ${doc.ref.path}`);
      console.log(`   Has expiresAt: ${data.expiresAt ? '✅' : '❌'}`);
      if (data.expiresAt) {
        console.log(`   expiresAt: ${data.expiresAt.toDate().toISOString()}`);
      }
      console.log(`   Other fields: ${Object.keys(data).join(', ')}`);
      console.log();
    }
    
    // Check if there are any direct tasks collections (not subcollections)
    console.log('🔍 Checking for direct tasks collections...');
    
    try {
      // Try to find tasks at organization level
      const orgs = await db.collection('organizations').limit(5).get();
      
      for (const org of orgs.docs) {
        console.log(`\n🏢 Org: ${org.id}`);
        
        // Check if this org has a direct tasks collection
        try {
          const directTasks = await org.ref.collection('tasks').limit(3).get();
          if (!directTasks.empty) {
            console.log(`   ✅ Found ${directTasks.size} direct tasks in org`);
            for (const task of directTasks.docs) {
              const data = task.data();
              console.log(`     Task ${task.id}: expiresAt = ${data.expiresAt ? '✅' : '❌'}`);
            }
          } else {
            console.log(`   ❌ No direct tasks collection in org`);
          }
        } catch (e) {
          console.log(`   ❌ Error checking direct tasks: ${e.message}`);
        }
        
        // Check locations within this org
        try {
          const locations = await org.ref.collection('locations').limit(3).get();
          for (const loc of locations.docs) {
            console.log(`   📍 Location: ${loc.id}`);
            
            // Check for direct tasks in location
            try {
              const locTasks = await loc.ref.collection('tasks').limit(2).get();
              if (!locTasks.empty) {
                console.log(`      ✅ Found ${locTasks.size} direct tasks in location`);
                for (const task of locTasks.docs) {
                  const data = task.data();
                  console.log(`        Task ${task.id}: expiresAt = ${data.expiresAt ? '✅' : '❌'}`);
                }
              } else {
                console.log(`      ❌ No direct tasks in location`);
              }
            } catch (e) {
              console.log(`      ❌ Error: ${e.message}`);
            }
          }
        } catch (e) {
          console.log(`   ❌ Error checking locations: ${e.message}`);
        }
      }
    } catch (error) {
      console.log(`❌ Error checking direct collections: ${error.message}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

debugTasksPaths().then(() => {
  console.log('\n✨ Debug complete!');
  process.exit(0);
});
