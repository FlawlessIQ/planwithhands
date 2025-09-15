import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Provides the count of unread (and unarchived) notifications for the current user
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final userState = ref.watch(userStateProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('[unreadNotificationsCountProvider] No user logged in.');
    return Stream.value(0);
  }
  // Defensive: Wait for userData to be loaded
  if (userState.userData == null) {
    debugPrint('[unreadNotificationsCountProvider] userData not loaded yet for user ${user.uid}. Returning 0 unread.');
    // Return 0 unread messages while user data loads
    return Stream.value(0);
  }
  final orgId = userState.userData!.organizationId;
  if (orgId.isEmpty) {
    debugPrint('[unreadNotificationsCountProvider] No organizationId for user ${user.uid}.');
    return Stream.value(0);
  }
  debugPrint('[unreadNotificationsCountProvider] Subscribing for orgId: $orgId, userId: ${user.uid}');

  return FirestoreEnforcer.instance
      .collection('userNotifications')
      .doc(user.uid)
      .collection('notifications')
      .snapshots()
      .map((snap) {
        debugPrint('[unreadNotificationsCountProvider] Snapshot received with ${snap.docs.length} docs.');
        final count =
            snap.docs.where((doc) {
              final data = doc.data();

              // For per-user notifications, we don't need targeting checks
              // They're already filtered by the Firebase Function
              final readBy = List<String>.from(data['readBy'] ?? []);
              final archivedBy = List<String>.from(data['archivedBy'] ?? []);
              final isUnread = !readBy.contains(user.uid) && !archivedBy.contains(user.uid);
              debugPrint(
                '[unreadNotificationsCountProvider] Doc ${doc.id}: readBy=$readBy, archivedBy=$archivedBy, isUnread=$isUnread',
              );
              return isUnread;
            }).length;
        debugPrint('[unreadNotificationsCountProvider] Final unread count: $count');
        return count;
      });
});

// Simple sealed class for NotificationState (no freezed)
abstract class NotificationState {
  const NotificationState();
}

class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

class NotificationSuccess extends NotificationState {
  const NotificationSuccess();
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);
}
