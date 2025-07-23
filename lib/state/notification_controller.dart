import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationControllerProvider = Provider<NotificationController>((ref) {
  return NotificationController();
});

class NotificationController {
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    String? groupId,
  }) async {
    // Implement your notification logic here
  }
}
