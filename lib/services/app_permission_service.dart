import 'package:hands_app/utils/app_platform.dart';
import 'package:permission_handler/permission_handler.dart';

/// App-specific permission types that map to the permissions we need
enum AppPermission { photos, calendar, notifications }

/// Service to handle native permission requests with graceful fallbacks
class AppPermissionService {
  static const AppPermissionService _instance = AppPermissionService._internal();

  const AppPermissionService._internal();

  factory AppPermissionService() => _instance;

  /// Request a specific app permission and return the status
  Future<PermissionStatus> requestPermission(AppPermission permission) async {
    final nativePermission = _mapToNativePermission(permission);
    if (nativePermission == null) {
      // Permission not applicable on this platform
      return PermissionStatus.granted;
    }

    // Check current status first
    final currentStatus = await nativePermission.status;

    // If already granted, return immediately
    if (currentStatus.isGranted) {
      return currentStatus;
    }

    // If permanently denied, don't request again
    if (currentStatus.isPermanentlyDenied) {
      return currentStatus;
    }

    // Request the permission
    final result = await nativePermission.request();
    return result;
  }

  /// Check if a permission is permanently denied
  Future<bool> isPermanentlyDenied(AppPermission permission) async {
    final nativePermission = _mapToNativePermission(permission);
    if (nativePermission == null) {
      return false;
    }

    final status = await nativePermission.status;
    return status.isPermanentlyDenied;
  }

  /// Check if a permission is currently granted
  Future<bool> isGranted(AppPermission permission) async {
    final nativePermission = _mapToNativePermission(permission);
    if (nativePermission == null) {
      return true; // Not applicable = granted
    }

    final status = await nativePermission.status;
    return status.isGranted;
  }

  /// Open device settings to allow user to manually grant permissions
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Map app permissions to platform-specific native permissions
  Permission? _mapToNativePermission(AppPermission permission) {
    switch (permission) {
      case AppPermission.photos:
        if (isIOS) {
          return Permission.photos;
        } else if (isAndroid) {
          // Use the new Android 13+ media permissions
          return Permission.photos;
        }
        return null;

      case AppPermission.calendar:
        // Using calendarFullAccess as it covers both read and write permissions
        return Permission.calendarFullAccess;

      case AppPermission.notifications:
        return Permission.notification;
    }
  }

  /// Get user-friendly description for permission rationale
  String getPermissionRationale(AppPermission permission) {
    switch (permission) {
      case AppPermission.photos:
        return 'Photos are used to document completed tasks and provide visual proof of work.';
      case AppPermission.calendar:
        return 'Calendar access allows you to sync your work schedule with your device calendar.';
      case AppPermission.notifications:
        return 'Notifications help you stay updated on schedule changes and important announcements.';
    }
  }

  /// Get user-friendly permission name
  String getPermissionName(AppPermission permission) {
    switch (permission) {
      case AppPermission.photos:
        return 'Photo Library';
      case AppPermission.calendar:
        return 'Calendar';
      case AppPermission.notifications:
        return 'Notifications';
    }
  }
}
