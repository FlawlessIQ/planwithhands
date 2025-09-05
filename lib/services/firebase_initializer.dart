import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:hands_app/services/push_notification_service.dart';

/// Simple Firebase initialization helper.
class FirebaseInitializer {
  static final FirebaseInitializer _instance = FirebaseInitializer._internal();
  factory FirebaseInitializer() => _instance;
  FirebaseInitializer._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // CRITICAL FIX: No longer skipping Firebase initialization for any browser
    // This ensures all browsers, including mobile Safari, can use the web app
    // DEBUGGING: Added additional safeguards and error info

    try {
      // Enhanced debug logging
      debugPrint('🔥 [FIREBASE] Starting initialization');
      debugPrint('🔥 [FIREBASE] Apps: ${Firebase.apps.length}');

      // If a Firebase app already exists (hot restart scenario), just mark initialized
      if (Firebase.apps.isNotEmpty) {
        debugPrint('🔥 [FIREBASE] Already initialized, using existing app: ${Firebase.apps.first.name}');
        _isInitialized = true;
        return;
      }

      // Initialize Firebase with platform-specific options
      debugPrint('🔥 [FIREBASE] Initializing with DefaultFirebaseOptions.currentPlatform');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('🔥 [FIREBASE] Initialization successful');

      // Register background message handler for non-web platforms only
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        debugPrint('🔥 [FIREBASE] Background message handler registered');
      }

      _isInitialized = true;
    } on FirebaseException catch (e) {
      // Handle duplicate-app exception gracefully
      if (e.code == 'duplicate-app') {
        debugPrint('🔥 [FIREBASE] Duplicate app exception handled gracefully');
        _isInitialized = true;
        return;
      }

      debugPrint('🔥 [FIREBASE] FirebaseException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('🔥 [FIREBASE] Unexpected error during initialization: $e');
      rethrow;
    }
  }
}
