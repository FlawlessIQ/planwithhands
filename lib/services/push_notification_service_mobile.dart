// Mobile push notification service - now redirects to main service
// This ensures compatibility while using the comprehensive push_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/push_notification_service.dart' as main_service;

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  // Delegate to the main push notification service
  final main_service.PushNotificationService _mainService = main_service.PushNotificationService();

  Future<void> initialize() async {
    if (kIsWeb) {
      logger.w('[PushNotificationService:Mobile] Web platform – delegating to main service.');
    }
    await _mainService.initialize();
  }

  Future<void> ensureRegistered() async {
    await _mainService.ensureRegistered();
  }

  Future<String?> getToken() async {
    return await _mainService.getToken();
  }

  Future<void> openAppSettings() async {
    await _mainService.openAppSettings();
  }

  void dispose() {
    _mainService.dispose();
  }
}

enum NotificationPermissionResult { granted, denied, notDetermined, error }
