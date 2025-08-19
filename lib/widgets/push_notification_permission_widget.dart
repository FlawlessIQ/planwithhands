import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/services/push_notification_service.dart';

/// Widget for managing push notification permissions with native dialogs
class PushNotificationPermissionWidget extends ConsumerStatefulWidget {
  /// Callback when permission is granted
  final VoidCallback? onPermissionGranted;

  /// Callback when permission is denied
  final VoidCallback? onPermissionDenied;

  /// Whether to show the permission request automatically
  final bool autoRequest;

  /// Custom title for the permission explanation
  final String? title;

  /// Custom message for the permission explanation
  final String? message;

  const PushNotificationPermissionWidget({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
    this.autoRequest = false,
    this.title,
    this.message,
  });

  @override
  ConsumerState<PushNotificationPermissionWidget> createState() => _PushNotificationPermissionWidgetState();
}

class _PushNotificationPermissionWidgetState extends ConsumerState<PushNotificationPermissionWidget> {
  final PushNotificationService _notificationService = PushNotificationService();
  NotificationPermissionResult _permissionStatus = NotificationPermissionResult.notDetermined;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissionStatus();

    if (widget.autoRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestPermissionWithExplanation();
      });
    }
  }

  Future<void> _checkInitialPermissionStatus() async {
    final status = await _notificationService.checkPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  Future<void> _requestPermissionWithExplanation() async {
    if (_permissionStatus == NotificationPermissionResult.granted) {
      widget.onPermissionGranted?.call();
      return;
    }

    // Show explanation before requesting permission (best practice)
    final shouldRequest = await _showPermissionExplanationDialog();
    if (!shouldRequest) return;

    await _requestPermission();
  }

  Future<bool> _showPermissionExplanationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(widget.title ?? 'Enable Notifications'),
              content: Text(
                widget.message ??
                    'Stay updated with your schedule changes, shift reminders, and important announcements. '
                        'We\'ll only send notifications that are relevant to your work.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not Now')),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Enable Notifications'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _notificationService.requestPermission();

      if (mounted) {
        setState(() {
          _permissionStatus = result;
          _isLoading = false;
        });

        switch (result) {
          case NotificationPermissionResult.granted:
            widget.onPermissionGranted?.call();
            _showSuccessSnackBar();
            break;
          case NotificationPermissionResult.denied:
            widget.onPermissionDenied?.call();
            _showDeniedDialog();
            break;
          case NotificationPermissionResult.notDetermined:
            // User dismissed the dialog, try again later
            break;
          case NotificationPermissionResult.error:
            _showErrorSnackBar();
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar();
      }
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Notifications enabled successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text('Error enabling notifications. Please try again.'),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showDeniedDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notifications Disabled'),
          content: const Text(
            'You can enable notifications anytime in your device settings:\n\n'
            '1. Go to Settings\n'
            '2. Find Hands app\n'
            '3. Tap Notifications\n'
            '4. Enable Allow Notifications',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Maybe Later')),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _notificationService.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionStatus == NotificationPermissionResult.granted) {
      return const SizedBox.shrink(); // Hide widget when permission is granted
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stay Connected',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get notified about schedule updates and shift reminders',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            // Hide the widget for this session
                            setState(() {
                              _permissionStatus = NotificationPermissionResult.denied;
                            });
                          },
                  child: const Text('Not Now'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _requestPermissionWithExplanation,
                  child:
                      _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple button widget for requesting push notification permission
class PushNotificationPermissionButton extends ConsumerStatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;

  const PushNotificationPermissionButton({
    super.key,
    this.label,
    this.icon,
    this.onPermissionGranted,
    this.onPermissionDenied,
  });

  @override
  ConsumerState<PushNotificationPermissionButton> createState() => _PushNotificationPermissionButtonState();
}

class _PushNotificationPermissionButtonState extends ConsumerState<PushNotificationPermissionButton> {
  final PushNotificationService _notificationService = PushNotificationService();
  bool _isLoading = false;

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _notificationService.requestPermission();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        switch (result) {
          case NotificationPermissionResult.granted:
            widget.onPermissionGranted?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case NotificationPermissionResult.denied:
            widget.onPermissionDenied?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(label: 'Settings', onPressed: () => _notificationService.openAppSettings()),
              ),
            );
            break;
          default:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(result.message), behavior: SnackBarBehavior.floating));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error requesting notification permission'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _isLoading ? null : _requestPermission,
      icon:
          _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(widget.icon ?? Icons.notifications),
      label: Text(widget.label ?? 'Enable Notifications'),
    );
  }
}
