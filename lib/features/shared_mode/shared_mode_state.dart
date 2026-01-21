import 'package:meta/meta.dart';

@immutable
class SharedModeState {
  final bool enabled;
  final String? ownerUserId;
  final String? ownerOrgId;
  final String? locationId;

  /// If null, the device is considered "locked" and must prompt for a user PIN.
  final String? activeUserId;
  final String? activeUserName;
  final String? activeUserEmail;

  /// True when Shared Mode is enabled but no active user is selected.
  bool get locked => enabled && activeUserId == null;

  const SharedModeState({
    required this.enabled,
    required this.ownerUserId,
    required this.ownerOrgId,
    required this.locationId,
    required this.activeUserId,
    required this.activeUserName,
    required this.activeUserEmail,
  });

  const SharedModeState.disabled()
    : enabled = false,
      ownerUserId = null,
      ownerOrgId = null,
      locationId = null,
      activeUserId = null,
      activeUserName = null,
      activeUserEmail = null;

  SharedModeState copyWith({
    bool? enabled,
    String? ownerUserId,
    String? ownerOrgId,
    String? locationId,
    String? activeUserId,
    String? activeUserName,
    String? activeUserEmail,
    bool clearActiveUser = false,
  }) {
    return SharedModeState(
      enabled: enabled ?? this.enabled,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerOrgId: ownerOrgId ?? this.ownerOrgId,
      locationId: locationId ?? this.locationId,
      activeUserId: clearActiveUser ? null : (activeUserId ?? this.activeUserId),
      activeUserName: clearActiveUser ? null : (activeUserName ?? this.activeUserName),
      activeUserEmail: clearActiveUser ? null : (activeUserEmail ?? this.activeUserEmail),
    );
  }
}
