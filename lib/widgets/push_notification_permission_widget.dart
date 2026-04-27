import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Widget for managing push notification permissions with enhanced UX
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

  /// Context for the permission request (used for analytics and UX)
  final String context;

  /// Whether to show as a card or inline
  final bool showAsCard;

  /// Custom description widget
  final Widget? customDescription;

  const PushNotificationPermissionWidget({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
    this.autoRequest = false,
    this.title,
    this.message,
    this.context = 'general',
    this.showAsCard = true,
    this.customDescription,
  });

  @override
  ConsumerState<PushNotificationPermissionWidget> createState() =>
      _PushNotificationPermissionWidgetState();
}

class _PushNotificationPermissionWidgetState
    extends ConsumerState<PushNotificationPermissionWidget> {
  final PushNotificationService _notificationService =
      PushNotificationService();
  NotificationPermissionResult _permissionStatus =
      NotificationPermissionResult.notDetermined;
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
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                widget.title ?? l10n.notificationOnboardingEnableTitle,
              ),
              content: Text(
                widget.message ?? l10n.pushPermissionExplanationBody,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.pushPermissionNotNow),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.notificationOnboardingEnableTitle),
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
      final result = await _notificationService.requestPermissionWithContext(
        context: widget.context,
      );

      if (mounted) {
        setState(() {
          _permissionStatus = result;
          _isLoading = false;
        });

        switch (result) {
          case NotificationPermissionResult.granted:
            widget.onPermissionGranted?.call();
            _showSuccessSnackBar();
            logger.d(
              '[PushNotificationPermissionWidget] Permission granted for context: ${widget.context}',
            );
            break;
          case NotificationPermissionResult.denied:
            widget.onPermissionDenied?.call();
            _showDeniedDialog();
            logger.w(
              '[PushNotificationPermissionWidget] Permission denied for context: ${widget.context}',
            );
            break;
          case NotificationPermissionResult.notDetermined:
            // User dismissed the dialog, try again later
            logger.d(
              '[PushNotificationPermissionWidget] Permission not determined for context: ${widget.context}',
            );
            break;
          case NotificationPermissionResult.error:
            _showErrorSnackBar();
            logger.e(
              '[PushNotificationPermissionWidget] Permission error for context: ${widget.context}',
            );
            break;
        }
      }
    } catch (e) {
      logger.e(
        '[PushNotificationPermissionWidget] Error requesting permission',
        e,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar();
      }
    }
  }

  void _showSuccessSnackBar() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(l10n.pushPermissionEnabledSuccess),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(l10n.pushPermissionError),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showDeniedDialog() async {
    final l10n = context.l10n;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.pushPermissionDisabledTitle),
          content: Text(l10n.pushPermissionDisabledBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.pushPermissionMaybeLater),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _notificationService.openAppSettings();
              },
              child: Text(l10n.pushPermissionOpenSettings),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.notificationOnboardingStayConnected,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.pushPermissionShortBody,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                              _permissionStatus =
                                  NotificationPermissionResult.denied;
                            });
                          },
                  child: Text(l10n.pushPermissionNotNow),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed:
                      _isLoading ? null : _requestPermissionWithExplanation,
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(l10n.notificationEnable),
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
  ConsumerState<PushNotificationPermissionButton> createState() =>
      _PushNotificationPermissionButtonState();
}

class _PushNotificationPermissionButtonState
    extends ConsumerState<PushNotificationPermissionButton> {
  final PushNotificationService _notificationService =
      PushNotificationService();
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
                action: SnackBarAction(
                  label: context.l10n.pushPermissionSettings,
                  onPressed: () => _notificationService.openAppSettings(),
                ),
              ),
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.pushPermissionRequestError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FilledButton.icon(
      onPressed: _isLoading ? null : _requestPermission,
      icon:
          _isLoading
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(widget.icon ?? Icons.notifications),
      label: Text(widget.label ?? l10n.notificationOnboardingEnableTitle),
    );
  }
}
