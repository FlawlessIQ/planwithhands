import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreConnectionDebug {
  static Future<void> checkFirestoreConnection() async {
    try {
      debugPrint('[FIRESTORE_DEBUG] Starting Firestore connection check...');

      // Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('[FIRESTORE_DEBUG] Current user: ${user?.uid ?? "Not authenticated"}');

      // Set offline persistence settings (applies on all platforms; safe no-op if already set)
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('[FIRESTORE_DEBUG] Firestore persistence enabled via settings');
      } catch (e) {
        debugPrint('[FIRESTORE_DEBUG] Could not apply Firestore settings: $e');
      }

      // Try a simple Firestore operation
      final testDoc = FirebaseFirestore.instance.collection('_test').doc('connection');

      // Test write operation
      debugPrint('[FIRESTORE_DEBUG] Testing write operation...');
      await testDoc.set({'timestamp': FieldValue.serverTimestamp(), 'test': true});
      debugPrint('[FIRESTORE_DEBUG] Write operation successful');

      // Test read operation
      debugPrint('[FIRESTORE_DEBUG] Testing read operation...');
      final snapshot = await testDoc.get();
      debugPrint('[FIRESTORE_DEBUG] Read operation successful: ${snapshot.exists}');

      // Clean up test document
      await testDoc.delete();
      debugPrint('[FIRESTORE_DEBUG] Cleanup successful');

      debugPrint('[FIRESTORE_DEBUG] ✅ Firestore connection is working properly');
    } catch (e) {
      debugPrint('[FIRESTORE_DEBUG] ❌ Firestore connection error: $e');

      // Provide specific troubleshooting advice
      if (e.toString().contains('PERMISSION_DENIED')) {
        debugPrint('[FIRESTORE_DEBUG] 💡 Check your Firestore security rules');
      } else if (e.toString().contains('UNAVAILABLE')) {
        debugPrint('[FIRESTORE_DEBUG] 💡 Network connectivity issue - check internet connection');
      } else if (e.toString().contains('UNAUTHENTICATED')) {
        debugPrint('[FIRESTORE_DEBUG] 💡 User authentication required');
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
        debugPrint('[FIRESTORE_DEBUG] Enhanced logging enabled');
      } catch (e) {
        debugPrint('[FIRESTORE_DEBUG] Could not enable enhanced logging: $e');
      }
    }
  }

  static Future<void> clearFirestoreCache() async {
    try {
      if (!kIsWeb) {
        await FirebaseFirestore.instance.clearPersistence();
        debugPrint('[FIRESTORE_DEBUG] Firestore cache cleared');
      } else {
        debugPrint('[FIRESTORE_DEBUG] Cache clearing not available on web');
      }
    } catch (e) {
      debugPrint('[FIRESTORE_DEBUG] Could not clear cache: $e');
    }
  }
}
