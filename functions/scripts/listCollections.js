#!/usr/bin/env node
/**
 * List all collections and their document counts in Firestore
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function listCollections() {
  try {
    console.log('🔍 Listing Firestore collections...\n');
    
    // Get top-level collections
    const collections = await db.listCollections();
    
    for (const collection of collections) {
      const snapshot = await collection.limit(5).get();
      console.log(`📁 ${collection.id} (${snapshot.size} docs shown, may have more)`);
      
      // Show first few documents
      for (const doc of snapshot.docs) {
        const data = doc.data();
        const hasExpiresAt = data.expiresAt ? '🔥 TTL' : '   ';
        console.log(`   ${hasExpiresAt} ${doc.ref.path}`);
      }
      
      if (snapshot.size === 0) {
        console.log(`   (empty collection)`);
      }
      console.log();
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

listCollections().then(() => {
  console.log('✨ Done listing collections');
  process.exit(0);
});
