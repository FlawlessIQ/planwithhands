import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hands_app/platform/user_agent_stub.dart'
    if (dart.library.html) 'package:hands_app/platform/user_agent_web.dart';
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

    // Skip only for mobile Safari (identified by UA) unless query param forceApp present
    if (kIsWeb) {
      final ua = getUserAgent().toLowerCase();
      final isIOS = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
      final isSafari =
          ua.contains('safari') && !ua.contains('crios') && !ua.contains('chrome') && !ua.contains('fxios');
      final forceApp = Uri.base.queryParameters.containsKey('forceApp');
      if (isIOS && isSafari && !forceApp) {
        // Bypass Firebase only in this problematic environment
        _isInitialized = true;
        return;
      }
    }

    try {
      // If a Firebase app already exists (hot restart scenario), just mark initialized
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        return;
      }

      // Initialize Firebase (native platforms only)
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _isInitialized = true;
    } on FirebaseException catch (e) {
      // Swallow duplicate-app exception
      if (e.code == 'duplicate-app') {
        _isInitialized = true;
        return;
      }
      rethrow;
    }
  }
}
