import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'dart:async';

/// Notifier for managing notification state refresh
class NotificationStateNotifier extends Notifier<int> {
  StreamSubscription? _subscription;
  Timer? _refreshTimer;

  @override
  int build() {
    // Start listening to notification count
    _startListening();

    // Set up periodic refresh for long-running sessions
    _setupPeriodicRefresh();

    // Cleanup when disposed
    ref.onDispose(() {
      _subscription?.cancel();
      _refreshTimer?.cancel();
      debugPrint('[NotificationStateNotifier] Disposed notification listeners');
    });

    return 0;
  }

  void _startListening() {
    final userState = ref.watch(userStateProvider);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('[NotificationStateNotifier] No user logged in.');
      state = 0;
      return;
    }

    // Wait for userData to be loaded before subscribing to notifications
    if (userState.userData == null) {
      debugPrint('[NotificationStateNotifier] userData not loaded yet for user ${user.uid}. Waiting...');
      state = 0;
      return;
    }

    final orgId = userState.userData!.organizationId;
    if (orgId.isEmpty) {
      debugPrint('[NotificationStateNotifier] No organizationId for user ${user.uid}.');
      state = 0;
      return;
    }

    debugPrint('[NotificationStateNotifier] Starting notification listener for orgId: $orgId, userId: ${user.uid}');

    // Cancel previous subscription
    _subscription?.cancel();

    _subscription = FirestoreEnforcer.instance
        .collection('userNotifications')
        .doc(user.uid)
        .collection('notifications')
        .snapshots()
        .listen(
          (snap) {
            debugPrint('[NotificationStateNotifier] Snapshot received with ${snap.docs.length} docs.');
            final count =
                snap.docs.where((doc) {
                  final data = doc.data();

                  // For per-user notifications, we don't need targeting checks
                  // They're already filtered by the Firebase Function
                  final readBy = List<String>.from(data['readBy'] ?? []);
                  final archivedBy = List<String>.from(data['archivedBy'] ?? []);
                  final isUnread = !readBy.contains(user.uid) && !archivedBy.contains(user.uid);

                  debugPrint(
                    '[NotificationStateNotifier] Doc ${doc.id}: readBy=$readBy, archivedBy=$archivedBy, isUnread=$isUnread',
                  );
                  return isUnread;
                }).length;

            debugPrint('[NotificationStateNotifier] Final unread count: $count');
            state = count;
          },
          onError: (error) {
            debugPrint('[NotificationStateNotifier] Stream error: $error');
            // Don't reset count on error, but log the issue
            // This prevents notification indicator from disappearing due to network issues
          },
        );
  }

  /// Set up periodic refresh for long-running sessions
  void _setupPeriodicRefresh() {
    _refreshTimer?.cancel();

    // Refresh notification listener every 30 minutes during active sessions
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      debugPrint('[NotificationStateNotifier] Periodic refresh triggered');
      _refreshListener();
    });
  }

  /// Force refresh the notification listener
  void _refreshListener() {
    debugPrint('[NotificationStateNotifier] Refreshing notification listener');
    _subscription?.cancel();
    _startListening();
  }

  /// Public method to manually refresh notifications (called from UI)
  void refresh() {
    _refreshListener();
  }
}

/// Provider for notification count with automatic refresh capabilities
final notificationCountProvider = NotifierProvider<NotificationStateNotifier, int>(() {
  return NotificationStateNotifier();
});

/// Legacy provider for backwards compatibility - now uses the new refreshable provider
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  // Watch the new provider and convert to stream
  final count = ref.watch(notificationCountProvider);
  return Stream.value(count);
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
