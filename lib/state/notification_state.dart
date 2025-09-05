import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/location_helper.dart';

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

  // Get user data for filtering
  final userData = {'userRole': userState.userData!.userRole, 'locationIds': userState.userData!.locationIds};

  return FirestoreEnforcer.instance.collection('organizations').doc(orgId).collection('notifications').snapshots().map((
    snap,
  ) {
    debugPrint('[unreadNotificationsCountProvider] Snapshot received with ${snap.docs.length} docs.');
    final count =
        snap.docs.where((doc) {
          final data = doc.data();

          // First check targeting - only count if user should see this notification
          if (!_shouldUserSeeNotification(data, userData, user.uid)) {
            return false;
          }

          final readBy = List<String>.from(data['readBy'] ?? []);
          final archivedBy = List<String>.from(data['archivedBy'] ?? []);
          final isUnread = !readBy.contains(user.uid) && !archivedBy.contains(user.uid);
          debugPrint('[unreadNotificationsCountProvider] Doc ${doc.id}: isUnread = $isUnread');
          return isUnread;
        }).length;
    debugPrint('[unreadNotificationsCountProvider] Final unread count: $count');
    return count;
  });
});

/// Determine if the current user should see this notification
bool _shouldUserSeeNotification(Map<String, dynamic> notificationData, Map<String, dynamic> userData, String userId) {
  final targetType = notificationData['targetType'] as String?;
  final targetId = notificationData['targetId'] as String?;
  final notificationType = notificationData['type'] as String?;
  final notificationUserId = notificationData['userId'] as String?;

  // Handle message notifications (created by messaging system)
  if (notificationType == 'message') {
    // Message notifications are user-specific and already have userId set
    return notificationUserId == userId;
  }

  // Handle legacy notifications and "all users" notifications
  if (targetType == null || targetType == 'all') {
    final recipientId = notificationData['recipientId'] as String?;
    // Show to all users if recipientId is 'all' or null
    return recipientId == 'all' || recipientId == null;
  }

  switch (targetType) {
    case 'all':
      return true;

    case 'user':
      // Individual user targeting
      return targetId == userId;

    case 'group':
      // Group targeting - check if user is member of the group
      // TODO: Implement group membership check when groups are fully implemented
      return false;

    case 'location':
      // Location targeting - check if user has access to this location
      return _userHasLocationAccess(userData, targetId);

    default:
      // Unknown target type - show to be safe
      return true;
  }
}

/// Check if user has access to the specified location
bool _userHasLocationAccess(Map<String, dynamic> userData, String? locationId) {
  if (locationId == null) return false;

  final userRole = userData['userRole'] as int? ?? 0;

  // Admins see all notifications
  if (userRole == 2) return true;

  // For managers and general users: canonicalize and check locationIds
  final locIds = coerceToLocationIds(userData['locationIds'] ?? userData['locationId']);
  return locIds.contains(locationId);
}

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
