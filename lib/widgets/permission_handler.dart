import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hands_app/services/app_permission_service.dart';

/// Widget that handles permission requests with user-friendly UI
class AppPermissionWidget extends StatefulWidget {
  final AppPermission permission;
  final Widget child;
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;
  final bool showBannerWhenDenied;

  const AppPermissionWidget({
    super.key,
    required this.permission,
    required this.child,
    this.onPermissionGranted,
    this.onPermissionDenied,
    this.showBannerWhenDenied = true,
  });

  @override
  State<AppPermissionWidget> createState() => _AppPermissionWidgetState();
}

class _AppPermissionWidgetState extends State<AppPermissionWidget> {
  final AppPermissionService _permissionService = AppPermissionService();
  bool _isPermanentlyDenied = false;
  bool _isGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final isGranted = await _permissionService.isGranted(widget.permission);
    final isPermanentlyDenied = await _permissionService.isPermanentlyDenied(widget.permission);

    if (mounted) {
      setState(() {
        _isGranted = isGranted;
        _isPermanentlyDenied = isPermanentlyDenied;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await _permissionService.requestPermission(widget.permission);

    if (mounted) {
      switch (status) {
        case PermissionStatus.granted:
          setState(() {
            _isGranted = true;
            _isPermanentlyDenied = false;
          });
          widget.onPermissionGranted?.call();
          _showSnackBar('Permission granted! You can now use this feature.', isError: false);
          break;

        case PermissionStatus.denied:
          setState(() {
            _isGranted = false;
            _isPermanentlyDenied = false;
          });
          widget.onPermissionDenied?.call();
          _showPermissionDeniedSnackBar();
          break;

        case PermissionStatus.permanentlyDenied:
          setState(() {
            _isGranted = false;
            _isPermanentlyDenied = true;
          });
          widget.onPermissionDenied?.call();
          _showPermissionDeniedSnackBar();
          break;

        default:
          // Handle other statuses if needed
          break;
      }
    }
  }

  void _showPermissionDeniedSnackBar() {
    final permissionName = _permissionService.getPermissionName(widget.permission);
    final rationale = _permissionService.getPermissionRationale(widget.permission);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$permissionName access is needed'),
            const SizedBox(height: 4),
            Text(rationale, style: const TextStyle(fontSize: 12)),
          ],
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () async {
            final opened = await _permissionService.openSettings();
            if (!opened && mounted) {
              _showSnackBar('Could not open settings. Please manually enable permissions.', isError: true);
            }
          },
        ),
        duration: const Duration(seconds: 6),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.child;
    }

    return Column(
      children: [
        // Show banner when permanently denied
        if (_isPermanentlyDenied && widget.showBannerWhenDenied)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_permissionService.getPermissionName(widget.permission)} access is disabled. Tap to enable in settings.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _permissionService.openSettings,
                  child: Text('Settings', style: TextStyle(color: Colors.orange.shade700)),
                ),
              ],
            ),
          ),

        // Main content
        widget.child,
      ],
    );
  }

  /// Static method to request permission with user action trigger
  static Future<bool> requestPermissionOnAction(
    BuildContext context,
    AppPermission permission, {
    VoidCallback? onGranted,
    VoidCallback? onDenied,
  }) async {
    final service = AppPermissionService();

    // Check if already granted
    if (await service.isGranted(permission)) {
      onGranted?.call();
      return true;
    }

    // Check if permanently denied
    if (await service.isPermanentlyDenied(permission)) {
      onDenied?.call();
      AppPermissionUtils._showPermanentlyDeniedDialog(context, permission, service);
      return false;
    }

    // Request permission
    final status = await service.requestPermission(permission);

    if (status.isGranted) {
      onGranted?.call();
      return true;
    } else {
      onDenied?.call();
      AppPermissionUtils._showPermissionDeniedDialog(context, permission, service);
      return false;
    }
  }
}

/// Utility class for permission-related operations
class AppPermissionUtils {
  static Future<bool> requestPermissionOnAction(
    BuildContext context,
    AppPermission permission, {
    VoidCallback? onGranted,
    VoidCallback? onDenied,
  }) async {
    final service = AppPermissionService();

    // Check if already granted
    if (await service.isGranted(permission)) {
      onGranted?.call();
      return true;
    }

    // Check if permanently denied
    if (await service.isPermanentlyDenied(permission)) {
      onDenied?.call();
      _showPermanentlyDeniedDialog(context, permission, service);
      return false;
    }

    // Request permission
    final status = await service.requestPermission(permission);

    if (status.isGranted) {
      onGranted?.call();
      return true;
    } else {
      onDenied?.call();
      _showPermissionDeniedDialog(context, permission, service);
      return false;
    }
  }

  static void _showPermissionDeniedDialog(
    BuildContext context,
    AppPermission permission,
    AppPermissionService service,
  ) {
    final permissionName = service.getPermissionName(permission);
    final rationale = service.getPermissionRationale(permission);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$permissionName Permission'),
            content: Text(rationale),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await service.openSettings();
                },
                child: const Text('Settings'),
              ),
            ],
          ),
    );
  }

  static void _showPermanentlyDeniedDialog(
    BuildContext context,
    AppPermission permission,
    AppPermissionService service,
  ) {
    final permissionName = service.getPermissionName(permission);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$permissionName Required'),
            content: Text(
              'This feature requires $permissionName permission. Please enable it in your device settings to continue.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await service.openSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }
}
