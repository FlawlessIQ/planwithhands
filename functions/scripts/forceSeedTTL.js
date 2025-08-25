#!/usr/bin/env node
/**
 * Force seed expiresAt field specifically for daily_checklists collection
 * This ensures the field appears in Firebase Console TTL policy setup
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function forceSeedDailyChecklists() {
  try {
    console.log('🔥 Force seeding expiresAt for daily_checklists...\n');
    
    // Query all daily_checklists using collectionGroup
    const query = db.collectionGroup('daily_checklists').limit(10);
    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.size} daily_checklist documents`);
    
    let updatedCount = 0;
    const batch = db.batch();
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Create a TTL timestamp for 30 days from now
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      );
      
      console.log(`📝 Processing: ${doc.ref.path}`);
      
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
    
    console.log('\n🎯 Next steps:');
    console.log('1. Wait 5-10 minutes for indexing to complete');
    console.log('2. Go to Firebase Console > Firestore Database');
    console.log('3. Click on any daily_checklists document');
    console.log('4. Look for "expiresAt" field in the document');
    console.log('5. Try creating TTL policy again');
    console.log('   - Field name: expiresAt');
    console.log('   - Collection group: daily_checklists');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

forceSeedDailyChecklists().then(() => {
  console.log('\n✨ Force seeding completed!');
  process.exit(0);
});
