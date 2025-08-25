#!/usr/bin/env node
/**
 * List subcollections within organizations and check for TTL fields
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function listSubcollections() {
  try {
    console.log('🔍 Checking subcollections in organizations...\n');
    
    // Check first organization
    const orgs = await db.collection('organizations').limit(2).get();
    
    for (const orgDoc of orgs.docs) {
      console.log(`🏢 Organization: ${orgDoc.id}`);
      
      // List subcollections
      const subcollections = await orgDoc.ref.listCollections();
      
      for (const subcollection of subcollections) {
        console.log(`  📁 ${subcollection.id}`);
        
        // Check for documents in this subcollection
        const snapshot = await subcollection.limit(3).get();
        
        if (snapshot.empty) {
          console.log(`     (empty)`);
        } else {
          for (const doc of snapshot.docs) {
            const data = doc.data();
            const hasExpiresAt = data.expiresAt ? '🔥' : '  ';
            console.log(`     ${hasExpiresAt} ${doc.ref.path}`);
            
            // Check for nested subcollections
            const nestedCollections = await doc.ref.listCollections();
            for (const nested of nestedCollections) {
              console.log(`        📁 ${nested.id}`);
              const nestedSnapshot = await nested.limit(2).get();
              for (const nestedDoc of nestedSnapshot.docs) {
                const nestedData = nestedDoc.data();
                const nestedHasTTL = nestedData.expiresAt ? '🔥' : '  ';
                console.log(`           ${nestedHasTTL} ${nestedDoc.ref.path}`);
              }
            }
          }
        }
      }
      console.log();
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

listSubcollections().then(() => {
  console.log('✨ Done checking subcollections');
  process.exit(0);
});
