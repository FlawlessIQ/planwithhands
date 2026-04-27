import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/services/push_notification_service.dart';

/// Widget for managing notification settings and preferences
class NotificationSettingsWidget extends ConsumerStatefulWidget {
  final Map<String, bool>? initialSettings;
  final Function(Map<String, bool>)? onSettingsChanged;

  const NotificationSettingsWidget({
    super.key,
    this.initialSettings,
    this.onSettingsChanged,
  });

  @override
  ConsumerState<NotificationSettingsWidget> createState() =>
      _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState
    extends ConsumerState<NotificationSettingsWidget> {
  final PushNotificationService _notificationService =
      PushNotificationService();

  late Map<String, bool> _settings;
  NotificationPermissionResult _permissionStatus =
      NotificationPermissionResult.notDetermined;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _settings = Map<String, bool>.from(
      widget.initialSettings ??
          {
            'scheduleUpdates': true,
            'shiftReminders': true,
            'generalAnnouncements': true,
            'pushNotifications': true,
            'emailNotifications': true,
          },
    );
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final status = await _notificationService.checkPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
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

        if (result.isGranted) {
          _updateSetting('pushNotifications', true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateSetting(String key, bool value) {
    setState(() {
      _settings[key] = value;
    });
    widget.onSettingsChanged?.call(_settings);
  }

  Future<void> _showTopicManagementDialog() async {
    final l10n = context.l10n;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.notificationTopicsTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.notificationTopicsIntro),
              const SizedBox(height: 16),
              Text(l10n.notificationTopicsScheduleUpdates),
              Text(l10n.notificationTopicsShiftReminders),
              Text(l10n.notificationTopicsGeneralAnnouncements),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.notificationTopicsGotIt),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.notificationSettingsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _showTopicManagementDialog,
                  icon: const Icon(Icons.info_outline),
                  tooltip: l10n.notificationTypesLearnMore,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Push Notifications Master Switch
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    _permissionStatus.isGranted
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _permissionStatus.isGranted
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color:
                        _permissionStatus.isGranted
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.notificationPushTitle,
                          style: TextStyle(
                            color:
                                _permissionStatus.isGranted
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _permissionStatus.isGranted
                              ? l10n.notificationPushEnabled
                              : l10n.notificationPushTapToEnable,
                          style: TextStyle(
                            color:
                                _permissionStatus.isGranted
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_permissionStatus.isGranted)
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : FilledButton(
                          onPressed: _requestPermission,
                          child: Text(l10n.notificationEnable),
                        )
                  else
                    Switch(
                      value: _settings['pushNotifications'] ?? false,
                      onChanged:
                          (value) => _updateSetting('pushNotifications', value),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Individual notification settings
            if (_permissionStatus.isGranted &&
                (_settings['pushNotifications'] ?? false)) ...[
              Text(
                l10n.notificationTypesTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              _buildNotificationToggle(
                'scheduleUpdates',
                l10n.notificationTypeScheduleUpdates,
                l10n.notificationTypeScheduleUpdatesBody,
                Icons.schedule,
              ),

              _buildNotificationToggle(
                'shiftReminders',
                l10n.notificationTypeShiftReminders,
                l10n.notificationTypeShiftRemindersBody,
                Icons.alarm,
              ),

              _buildNotificationToggle(
                'generalAnnouncements',
                l10n.notificationTypeGeneralAnnouncements,
                l10n.notificationTypeGeneralAnnouncementsBody,
                Icons.campaign,
              ),

              const Divider(),

              _buildNotificationToggle(
                'emailNotifications',
                l10n.notificationTypeEmail,
                l10n.notificationTypeEmailBody,
                Icons.email,
              ),
            ],

            // Show current FCM token in debug mode
            if (kDebugMode) ...[
              const Divider(),
              ExpansionTile(
                title: Text(l10n.notificationDebugInfo),
                children: [
                  FutureBuilder<String?>(
                    future: Future.value(_notificationService.currentToken),
                    builder: (context, snapshot) {
                      return ListTile(
                        title: Text(l10n.notificationFcmToken),
                        subtitle: Text(
                          snapshot.data?.substring(0, 50) ??
                              l10n.notificationNoToken,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                        trailing:
                            snapshot.data != null
                                ? IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    // Copy to clipboard
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.notificationTokenCopied,
                                        ),
                                      ),
                                    );
                                  },
                                )
                                : null,
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(
    String key,
    String title,
    String subtitle,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: _settings[key] ?? false,
        onChanged: (value) => _updateSetting(key, value),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Simplified notification status indicator
class NotificationStatusIndicator extends ConsumerStatefulWidget {
  const NotificationStatusIndicator({super.key});

  @override
  ConsumerState<NotificationStatusIndicator> createState() =>
      _NotificationStatusIndicatorState();
}

class _NotificationStatusIndicatorState
    extends ConsumerState<NotificationStatusIndicator> {
  final PushNotificationService _notificationService =
      PushNotificationService();
  NotificationPermissionResult _permissionStatus =
      NotificationPermissionResult.notDetermined;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final status = await _notificationService.checkPermissionStatus();
    if (mounted) {
      setState(() {
        _permissionStatus = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (_permissionStatus) {
      case NotificationPermissionResult.granted:
        icon = Icons.notifications_active;
        color = Colors.green;
        break;
      case NotificationPermissionResult.denied:
        icon = Icons.notifications_off;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications_none;
        color = Colors.orange;
    }

    return Icon(icon, color: color, size: 20);
  }
}
