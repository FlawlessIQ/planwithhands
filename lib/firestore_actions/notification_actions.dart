import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationActions {
  /// Create a notification with targets map and readBy array
  static Future<void> createNotification({
    required String orgId,
    required String notificationId,
    required Map<String, dynamic> notificationData, // Should include targets map and readBy array
  }) async {
    final notifRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('notifications')
        .doc(notificationId);
    await notifRef.set(notificationData);
  }

  /// Update a notification (e.g., add userId to readBy)
  static Future<void> updateNotification({
    required String orgId,
    required String notificationId,
    required Map<String, dynamic> updates, // e.g., {'readBy': FieldValue.arrayUnion([userId])}
  }) async {
    final notifRef = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('notifications')
        .doc(notificationId);
    await notifRef.update(updates);
  }
}
