import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Provides the count of unread (and unarchived) notifications for the current user
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final userState = ref.watch(userStateProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('[unreadNotificationsCountProvider] No user logged in.');
    return Stream.value(0);
  }
  // Defensive: Wait for userData to be loaded
  if (userState.userData == null) {
    print('[unreadNotificationsCountProvider] userData not loaded yet for user ${user.uid}. Returning loading stream.');
    // Return a stream that never emits, so the UI stays loading
    return const Stream<int>.empty();
  }
  final orgId = userState.userData!.organizationId;
  if (orgId.isEmpty) {
    print('[unreadNotificationsCountProvider] No organizationId for user ${user.uid}.');
    return Stream.value(0);
  }
  print('[unreadNotificationsCountProvider] Subscribing for orgId: $orgId, userId: ${user.uid}');
  return FirestoreEnforcer.instance
      .collection('organizations')
      .doc(orgId)
      .collection('notifications')
      .snapshots()
      .map((snap) {
        print('[unreadNotificationsCountProvider] Snapshot received with ${snap.docs.length} docs.');
        final count = snap.docs.where((doc) {
            final data = doc.data();
            final readBy = List<String>.from(data['readBy'] ?? []);
            final archivedBy = List<String>.from(data['archivedBy'] ?? []);
            final isUnread = !readBy.contains(user.uid) && !archivedBy.contains(user.uid);
            print('[unreadNotificationsCountProvider] Doc ${doc.id}: isUnread = $isUnread');
            return isUnread;
          }).length;
        print('[unreadNotificationsCountProvider] Final unread count: $count');
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
