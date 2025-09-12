import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

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
    // Determine organization ID from current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not signed in');
    }
    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    final orgId = userDoc.data()?['organizationId'] as String?;
    if (orgId == null) {
      throw Exception('Organization ID not found for user');
    }

    // Prepare notification data
    final notifRef =
        FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('notificationOutbox').doc();

    // Build targeting data based on recipient type
    Map<String, dynamic> notificationData = {
      'title': title,
      'message': body,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
      'archivedBy': <String>[],
    };

    // Handle different targeting types
    if (groupId != null && groupId.isNotEmpty) {
      // Group notification
      notificationData['targetType'] = 'group';
      notificationData['targetId'] = groupId;
      notificationData['recipientId'] = 'all'; // Legacy field
      notificationData['groupId'] = groupId; // Legacy field
    } else if (recipientId == 'all' || recipientId.isEmpty) {
      // All users notification
      notificationData['targetType'] = 'all';
      notificationData['recipientId'] = 'all';
    } else {
      // Location notification (recipientId contains location ID)
      notificationData['targetType'] = 'location';
      notificationData['targetId'] = recipientId;
      notificationData['recipientId'] = recipientId; // Legacy field
    }

    await notifRef.set(notificationData);
  }
}
