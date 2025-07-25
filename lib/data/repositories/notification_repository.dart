import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class NotificationRepository {
  final FirebaseFirestore firestore;
  NotificationRepository({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirestoreEnforcer.instance;

  // Fetch notifications for a user
  Stream<List<Map<String, dynamic>>> notificationsForUser(String userId) {
    return firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => {...doc.data(), 'id': doc.id})
                  .toList(),
        );
  }

  // Send a notification
  Future<void> sendNotification({
    required String orgId,
    required String recipientId,
    required String title,
    required String body,
    String? groupId,
  }) async {
    await firestore
        .collection('organizations')
        .doc(orgId)
        .collection('notifications')
        .add({
          'recipientId': recipientId,
          'title': title,
          'message': body,
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': [],
          if (groupId != null) 'groupId': groupId,
        });
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }
}
