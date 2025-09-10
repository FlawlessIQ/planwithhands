// Legacy mobile push notification service file replaced with minimal stub.
// Original content stored in push_notification_service_mobile.legacy.backup

import 'package:flutter/foundation.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _isInitialized = false;
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      logger.w('[PushNotificationService:Stub] Web platform – no mobile push init.');
      _isInitialized = true;
      return;
    }
    // Intentionally minimal – real implementation removed.
    _isInitialized = true;
    logger.w('[PushNotificationService:Stub] Initialized (stub).');
  }

  Future<void> ensureRegistered() async {}
  Future<String?> getToken() async => FirebaseMessaging.instance.getToken();
  Future<void> openAppSettings() async {
    logger.w('[PushNotificationService:Stub] openAppSettings() no-op.');
  }
  void dispose() {}
}

enum NotificationPermissionResult { granted, denied, notDetermined, error }
