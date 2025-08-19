import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/core/logging/logger.dart';

class FirestoreConnectionDebug {
  static Future<void> checkFirestoreConnection() async {
    try {
  logger.d('[FIRESTORE_DEBUG] Starting Firestore connection check...');

      // Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
  logger.d('[FIRESTORE_DEBUG] Current user: ${user?.uid ?? "Not authenticated"}');

      // Set offline persistence settings (applies on all platforms; safe no-op if already set)
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
  logger.d('[FIRESTORE_DEBUG] Firestore persistence enabled via settings');
      } catch (e) {
  logger.e('[FIRESTORE_DEBUG] Could not apply Firestore settings: $e', e);
      }

      // Try a simple Firestore operation
      final testDoc = FirebaseFirestore.instance.collection('_test').doc('connection');

      // Test write operation
  logger.d('[FIRESTORE_DEBUG] Testing write operation...');
      await testDoc.set({'timestamp': FieldValue.serverTimestamp(), 'test': true});
  logger.d('[FIRESTORE_DEBUG] Write operation successful');

      // Test read operation
  logger.d('[FIRESTORE_DEBUG] Testing read operation...');
      final snapshot = await testDoc.get();
  logger.d('[FIRESTORE_DEBUG] Read operation successful: ${snapshot.exists}');

      // Clean up test document
      await testDoc.delete();
  logger.d('[FIRESTORE_DEBUG] Cleanup successful');

  logger.i('[FIRESTORE_DEBUG] ✅ Firestore connection is working properly');
    } catch (e) {
  logger.e('[FIRESTORE_DEBUG] ❌ Firestore connection error: $e', e);

      // Provide specific troubleshooting advice
      if (e.toString().contains('PERMISSION_DENIED')) {
  logger.w('[FIRESTORE_DEBUG] 💡 Check your Firestore security rules');
      } else if (e.toString().contains('UNAVAILABLE')) {
  logger.w('[FIRESTORE_DEBUG] 💡 Network connectivity issue - check internet connection');
      } else if (e.toString().contains('UNAUTHENTICATED')) {
  logger.w('[FIRESTORE_DEBUG] 💡 User authentication required');
      }
    }
  }

  static Future<void> enableFirestoreLogging() async {
    if (kDebugMode) {
      try {
        // Enable detailed Firestore logging
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
  logger.d('[FIRESTORE_DEBUG] Enhanced logging enabled');
      } catch (e) {
  logger.e('[FIRESTORE_DEBUG] Could not enable enhanced logging: $e', e);
      }
    }
  }

  static Future<void> clearFirestoreCache() async {
    try {
      if (!kIsWeb) {
        await FirebaseFirestore.instance.clearPersistence();
  logger.d('[FIRESTORE_DEBUG] Firestore cache cleared');
      } else {
  logger.d('[FIRESTORE_DEBUG] Cache clearing not available on web');
      }
    } catch (e) {
  logger.e('[FIRESTORE_DEBUG] Could not clear cache: $e', e);
    }
  }
}
