import 'package:flutter/foundation.dart';
import 'package:hands_app/services/push_notification_service.dart';

class TokenRegistrationService {
  static Future<void> registerCurrentDevice(String userId) async {
    try {
      debugPrint(
        '[TokenRegistrationService] Registering current device for user $userId',
      );
      await PushNotificationService().ensureRegistered(
        context: 'token_registration_service',
      );
    } catch (e) {
      debugPrint('[TokenRegistrationService] Failed to register token: $e');
    }
  }
}
