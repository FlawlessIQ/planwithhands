#!/usr/bin/env node
/**
 * Force seed expiresAt field specifically for tasks collection
 * This ensures the field appears in Firebase Console TTL policy setup
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function forceSeedTasks() {
  try {
    console.log('🔥 Force seeding expiresAt for tasks...\n');
    
    // Query all tasks using collectionGroup
    const query = db.collectionGroup('tasks').limit(20);
    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.size} task documents`);
    
    let updatedCount = 0;
    const batch = db.batch();
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const docPath = doc.ref.path;
      
      // Skip template tasks - only process daily tasks
      if (docPath.includes('checklist_templates')) {
        console.log(`⏭️  Skipping template task: ${docPath}`);
        continue;
      }
      
      // Create a TTL timestamp for 30 days from now
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      );
      
      console.log(`📝 Processing daily task: ${docPath}`);
      
      if (data.expiresAt) {
        console.log(`   ✅ Already has expiresAt: ${data.expiresAt.toDate().toISOString()}`);
        
        // Force update even if it exists to ensure proper indexing
        batch.update(doc.ref, { 
          expiresAt: expiresAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        updatedCount++;
        console.log(`   🔄 Force updated expiresAt: ${expiresAt.toDate().toISOString()}`);
      } else {
        // Add expiresAt field
        batch.update(doc.ref, { 
          expiresAt: expiresAt,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        updatedCount++;
        console.log(`   ➕ Added expiresAt: ${expiresAt.toDate().toISOString()}`);
      }
    }
    
    if (updatedCount > 0) {
      console.log(`\n💾 Committing ${updatedCount} updates...`);
      await batch.commit();
      console.log('✅ Batch committed successfully!');
    } else {
      console.log('\n⏭️  No updates needed');
    }
    
    console.log('\n🎯 Tasks TTL setup complete!');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

forceSeedTasks().then(() => {
  console.log('\n✨ Tasks force seeding completed!');
  process.exit(0);
});
