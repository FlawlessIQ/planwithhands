#!/usr/bin/env node
/**
 * Test script for TTL Helper functionality
 * Validates that expiresAt fields are being set correctly
 */

const admin = require("firebase-admin");
const FirestoreTTLHelper = require("../lib/firestoreTTLHelper");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

async function testTTLHelper() {
  console.log("🧪 Testing Firestore TTL Helper...");

  // Test 1: Check TTL collection mapping
  console.log("\n📋 Testing TTL collection mapping:");
  const testCollections = [
    'tasks', 'notifications', 'invites', 'daily_checklists',
    'users', 'organizations' // non-TTL collections
  ];

  for (const collection of testCollections) {
    const ttlDays = FirestoreTTLHelper.getTTLDaysForCollection(collection);
    const requiresTTL = FirestoreTTLHelper.requiresTTL(collection);
    console.log(`  ${collection}: ${requiresTTL ? `${ttlDays} days` : 'no TTL'}`);
  }

  // Test 2: Path analysis
  console.log("\n🔍 Testing path analysis:");
  const testPaths = [
    'notifications/notif123',
    'organizations/org1/notifications/notif456', 
    'organizations/org1/locations/loc1/daily_checklists/check1',
    'organizations/org1/locations/loc1/daily_checklists/check1/tasks/task1',
    'users/user123',
    'invites/invite789'
  ];

  for (const path of testPaths) {
    const collectionName = FirestoreTTLHelper.getCollectionNameFromPath(path);
    const ttlDays = collectionName ? FirestoreTTLHelper.getTTLDaysForCollection(collectionName) : null;
    console.log(`  ${path} → ${collectionName || 'unknown'} ${ttlDays ? `(${ttlDays}d)` : ''}`);
  }

  // Test 3: Data enhancement
  console.log("\n⚡ Testing data enhancement:");
  const testData = { title: 'Test', message: 'Hello' };
  
  const enhancedNotification = FirestoreTTLHelper.addExpiresAtToData('notifications', testData);
  const enhancedUser = FirestoreTTLHelper.addExpiresAtToData('users', testData);
  const alreadyHasExpires = FirestoreTTLHelper.addExpiresAtToData('notifications', 
    { ...testData, expiresAt: new Date() });

  console.log(`  notifications: ${enhancedNotification.expiresAt ? '✅ expiresAt added' : '❌ no expiresAt'}`);
  console.log(`  users: ${enhancedUser.expiresAt ? '❌ unexpected expiresAt' : '✅ no expiresAt (correct)'}`);
  console.log(`  existing expiresAt: ${alreadyHasExpires.expiresAt instanceof Date ? '✅ preserved' : '❌ not preserved'}`);

  // Test 4: Live Firestore test (if not in dry-run mode)
  const isDryRun = process.argv.includes('--dry-run');
  
  if (!isDryRun) {
    console.log("\n🔥 Testing live Firestore operations:");
    
    try {
      // Test notification with TTL
      const notifRef = db.collection('debug_notifications').doc();
      await FirestoreTTLHelper.setWithTTL(notifRef, {
        title: 'TTL Test Notification',
        message: 'This should have expiresAt field',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        testId: `ttl-test-${Date.now()}`
      });

      const notifDoc = await notifRef.get();
      const notifData = notifDoc.data();
      console.log(`  notification: ${notifData.expiresAt ? '✅ expiresAt set' : '❌ no expiresAt'}`);

      // Test user document (no TTL)
      const userRef = db.collection('users').doc(`test-user-${Date.now()}`);
      await FirestoreTTLHelper.setWithTTL(userRef, {
        name: 'Test User',
        email: 'test@example.com',
        testId: `ttl-test-${Date.now()}`
      });

      const userDoc = await userRef.get();
      const userData = userDoc.data();
      console.log(`  user doc: ${userData.expiresAt ? '❌ unexpected expiresAt' : '✅ no expiresAt (correct)'}`);

      // Clean up test docs
      await notifRef.delete();
      await userRef.delete();
      
    } catch (error) {
      console.error('❌ Live test failed:', error);
    }
  } else {
    console.log("\n🔒 Skipping live Firestore tests (dry-run mode)");
  }

  console.log("\n✅ TTL Helper tests completed!");
}

if (require.main === module) {
  testTTLHelper().catch(err => {
    console.error('💥 Test failed:', err);
    process.exit(1);
  });
}

module.exports = { testTTLHelper };
