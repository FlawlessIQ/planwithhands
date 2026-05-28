import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/widgets/push_notification_permission_widget.dart';
import 'package:hands_app/widgets/notification_settings_widget.dart';
import 'package:hands_app/l10n/l10n.dart';

/// Example page showing how to integrate push notifications
/// Add this to your settings page or onboarding flow
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  final PushNotificationService _notificationService =
      PushNotificationService();

  @override
  void initState() {
    super.initState();
    _setupNotificationListeners();
  }

  void _setupNotificationListeners() {
    // Listen for incoming messages while app is open
    _notificationService.onMessage.listen((message) {
      debugPrint(
        'Received message while app is open: ${message.notification?.title}',
      );

      // Show in-app notification or update UI
      _showInAppNotification(message);
    });

    // Listen for token changes (important for sending to server)
    _notificationService.onTokenRefresh.listen((token) {
      debugPrint('FCM token updated: ${token.substring(0, 20)}...');

      // Send updated token to your server
      _sendTokenToServer(token);
    });
  }

  void _showInAppNotification(RemoteMessage message) {
    final l10n = context.l10n;
    final notification = message.notification;
    if (notification != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.title != null)
                Text(
                  notification.title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (notification.body != null) Text(notification.body!),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: l10n.notificationsViewAction,
            onPressed: () {
              // Navigate to relevant screen based on message data
              _handleNotificationTap(message);
            },
          ),
        ),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Example: Navigate based on notification data
    final screen = message.data['screen'];
    final id = message.data['id'];

    switch (screen) {
      case 'schedule':
        // Navigate to schedule screen
        debugPrint('Navigating to schedule: $id');
        break;
      case 'shifts':
        // Navigate to shifts screen
        debugPrint('Navigating to shifts: $id');
        break;
      default:
        // Navigate to home or default screen
        debugPrint('Navigating to home');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      // TODO: Send token to your server
      // Example:
      // await ApiService.updateFCMToken(userId: currentUserId, token: token);
      debugPrint('Token would be sent to server: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('Error sending token to server: $e');
    }
  }

  Future<void> _subscribeToTopics() async {
    try {
      // Subscribe to relevant topics based on user's organization/location
      await _notificationService.subscribeToTopic('general');
      // await _notificationService.subscribeToTopic('org_${organizationId}');
      // await _notificationService.subscribeToTopic('location_${locationId}');

      debugPrint('Subscribed to notification topics');
    } catch (e) {
      debugPrint('Error subscribing to topics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationSettingsTitle),
        actions: [
          IconButton(
            onPressed: () async {
              // Test notification functionality
              await _testNotificationSetup();
            },
            icon: const Icon(Icons.bug_report),
            tooltip: l10n.notificationSettingsTestTooltip,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission request widget
            PushNotificationPermissionWidget(
              title: l10n.notificationPermissionTitle,
              message: l10n.notificationPermissionBody,
              autoRequest: false, // Don't auto-request, let user trigger it
            ),

            const SizedBox(height: 16),

            // Notification settings
            NotificationSettingsWidget(
              initialSettings: const {
                'scheduleUpdates': true,
                'shiftReminders': true,
                'generalAnnouncements': true,
                'pushNotifications': true,
                'emailNotifications': true,
              },
              onSettingsChanged: (settings) {
                debugPrint('Notification settings updated: $settings');
                // Save settings to user preferences
                _saveNotificationSettings(settings);
              },
            ),

            const SizedBox(height: 16),

            // Action buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.notificationSettingsQuickActions,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _subscribeToTopics,
                            icon: const Icon(Icons.topic),
                            label: Text(
                              l10n.notificationSettingsSubscribeTopics,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                () => _notificationService.openAppSettings(),
                            icon: const Icon(Icons.settings),
                            label: Text(
                              l10n.notificationSettingsSystemSettings,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotificationSettings(Map<String, bool> settings) async {
    try {
      // TODO: Save to user preferences/Firestore
      // await UserPreferences.saveNotificationSettings(settings);
      debugPrint('Saved notification settings: $settings');
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  Future<void> _testNotificationSetup() async {
    final l10n = context.l10n;
    final permissionStatus = await _notificationService.checkPermissionStatus();
    final token = _notificationService.currentToken;

    showDialog(
      context: context,
      builder:
          (context) => HandsDialog(
            title: l10n.notificationSettingsTestTitle,
            maxWidth: 460,
            actions: [
              HandsSecondaryButton(
                text: l10n.commonOk,
                onPressed: () => Navigator.pop(context),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notificationSettingsPermission(permissionStatus.name),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.notificationSettingsToken(
                    token != null
                        ? '${token.substring(0, 20)}...'
                        : l10n.notificationSettingsNone,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.notificationSettingsStatus(
                    permissionStatus.isGranted
                        ? l10n.notificationSettingsReady
                        : l10n.notificationSettingsNotReady,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

/// Widget to add to your onboarding flow
class OnboardingNotificationStep extends StatelessWidget {
  final VoidCallback? onComplete;

  const OnboardingNotificationStep({super.key, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_active,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),

          Text(
            l10n.notificationOnboardingStayConnected,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            l10n.notificationOnboardingBody,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          PushNotificationPermissionWidget(
            title: l10n.notificationOnboardingEnableTitle,
            message: l10n.notificationOnboardingEnableBody,
            onPermissionGranted: onComplete,
            onPermissionDenied: onComplete,
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: onComplete,
            child: Text(l10n.notificationOnboardingSkip),
          ),
        ],
      ),
    );
  }
}
