import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:hands_app/services/push_notification_service.dart';

/// Robust, hot-restart safe Firebase initialization helper.
///
/// Handles these cases:
/// - Normal cold start (no Firebase apps yet)
/// - Hot restart: Dart state reset but native Firebase app persists
/// - Concurrent (re-entrant) calls during startup
/// - Duplicate-app exception (swallowed & treated as initialized)
class FirebaseInitializer {
  static final FirebaseInitializer _instance = FirebaseInitializer._internal();
  factory FirebaseInitializer() => _instance;
  FirebaseInitializer._internal();

  bool _isInitialized = false;
  Future<void>? _initializing; // Tracks in-flight initialization

  Future<void> initialize() async {
    // Fast path if already marked initialized in this Dart VM life-cycle
    if (_isInitialized) return;

    // If another caller already kicked off initialization, await it
    if (_initializing != null) {
      return _initializing;
    }

    _initializing = _doInitialize();
    try {
      await _initializing;
    } finally {
      _initializing = null; // Clear once complete (success or tolerated failure)
    }
  }

  Future<void> _doInitialize() async {
    try {
      // If a native Firebase app already exists (hot restart scenario), just mark initialized.
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        return;
      }
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _isInitialized = true;
    } on FirebaseException catch (e) {
      // Swallow duplicate-app safely; another code path beat us to it.
      if (e.code == 'duplicate-app') {
        _isInitialized = true;
        return;
      }
      rethrow;
    }
  }
}
