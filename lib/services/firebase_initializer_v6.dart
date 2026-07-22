import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:hands_app/services/push_notification_service.dart';

class FirebaseInitializerV6 {
  static final FirebaseInitializerV6 _instance = FirebaseInitializerV6._internal();
  factory FirebaseInitializerV6() => _instance;
  FirebaseInitializerV6._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🔥 [FIREBASE] Starting initialization');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('🔥 [FIREBASE] Initialization successful');

      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        debugPrint('🔥 [FIREBASE] Background message handler registered');
      }

      _initialized = true;
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        debugPrint('🔥 [FIREBASE] Duplicate app exception handled gracefully');
        _initialized = true;
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
