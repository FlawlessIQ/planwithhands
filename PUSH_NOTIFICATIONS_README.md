# Push Notifications Implementation for Hands App

This document outlines the complete native push notification implementation for the Hands Flutter app, targeting iOS 17+ and Android 15 (API 34).

## Overview

The implementation provides:
- ✅ Native iOS push notifications via APNs
- ✅ Native Android push notifications via FCM
- ✅ Native permission requests (no custom modals)
- ✅ Foreground and background message handling
- ✅ App Store review ready implementation
- ✅ Rich media support (optional service extension)
- ✅ Topic-based subscriptions
- ✅ Comprehensive error handling

## Files Created/Modified

### Core Service
- `lib/services/push_notification_service.dart` - Main notification service
- `lib/main.dart` - Updated with Firebase initialization and background handler

### UI Components
- `lib/widgets/push_notification_permission_widget.dart` - Permission request UI
- `lib/widgets/notification_settings_widget.dart` - Settings management UI
- `lib/pages/notification_settings_page.dart` - Complete example implementation

### iOS Implementation
- `ios/Runner/AppDelegate.swift` - Updated with notification delegate
- `ios/NotificationService/NotificationService.swift` - Service extension for rich media
- `ios/NotificationService/Info.plist` - Service extension configuration

### Android Implementation
- `android/app/src/main/kotlin/com/example/hands_clean/MainActivity.kt` - Updated for notification intents
- `android/app/src/main/kotlin/com/example/hands_clean/MyFirebaseMessagingService.kt` - Custom FCM service
- `android/app/src/main/AndroidManifest.xml` - Updated with FCM configuration

### Dependencies
- `pubspec.yaml` - Added firebase_messaging and flutter_local_notifications

## Features

### 1. Native Permission Handling
```dart
// Request permissions using native system dialog
final result = await PushNotificationService().requestPermission();

// Check current status
final status = await PushNotificationService().checkPermissionStatus();
```

### 2. Message Handling
```dart
// Listen for foreground messages
PushNotificationService().onMessage.listen((message) {
  // Handle incoming message while app is open
});

// Background messages are handled automatically by the service
```

### 3. Token Management
```dart
// Get current token
final token = PushNotificationService().currentToken;

// Listen for token updates
PushNotificationService().onTokenRefresh.listen((token) {
  // Send updated token to your server
});
```

### 4. Topic Subscriptions
```dart
// Subscribe to topics
await PushNotificationService().subscribeToTopic('general');
await PushNotificationService().subscribeToTopic('org_${organizationId}');

// Unsubscribe
await PushNotificationService().unsubscribeFromTopic('general');
```

## Usage Examples

### 1. Settings Page Integration
Add the notification settings widget to your settings page:

```dart
NotificationSettingsWidget(
  initialSettings: userSettings,
  onSettingsChanged: (settings) {
    // Save settings to user preferences
  },
)
```

### 2. Onboarding Flow
Add permission request to your onboarding:

```dart
PushNotificationPermissionWidget(
  title: 'Stay Updated',
  message: 'Get notified about schedule changes and shift reminders.',
  onPermissionGranted: () => nextStep(),
  onPermissionDenied: () => nextStep(),
)
```

### 3. Manual Permission Request
Request permissions with a simple button:

```dart
PushNotificationPermissionButton(
  label: 'Enable Notifications',
  onPermissionGranted: () {
    // Permission granted
  },
)
```

## App Store Review Guidelines

### iOS Compliance
- ✅ Uses native UNUserNotificationCenter permission dialog
- ✅ Requests permission only on user action, not at app launch
- ✅ Provides clear explanation before requesting permission
- ✅ Gracefully handles denied permissions with settings guidance
- ✅ Supports foreground notification display
- ✅ Implements proper APNs token handling

### Android Compliance
- ✅ Uses Android 13+ notification runtime permissions
- ✅ Creates proper notification channels
- ✅ Handles notification clicks correctly
- ✅ Supports background and foreground notifications

## Testing

### Debug Token Logging
In debug mode, FCM tokens are logged to console:
```
[FCM] Initial token: APA91bE...
[FCM] Token refreshed: APA91bE...
```

### Test Notifications
Use the debug button in NotificationSettingsPage to verify setup:
- Permission status
- Token availability
- Service initialization

### Firebase Console Testing
1. Go to Firebase Console > Cloud Messaging
2. Send test message using the logged FCM token
3. Test both foreground and background scenarios

## Server Integration

### Token Management
Send tokens to your server when they refresh:

```dart
PushNotificationService().onTokenRefresh.listen((token) async {
  await ApiService.updateFCMToken(
    userId: currentUserId, 
    token: token
  );
});
```

### Message Payload
Structure your server messages like this:

```json
{
  "notification": {
    "title": "Schedule Updated",
    "body": "Your schedule for next week has been published"
  },
  "data": {
    "screen": "schedule",
    "id": "schedule_123",
    "organization_id": "org_456"
  }
}
```

## Troubleshooting

### Common Issues

1. **No token received**
   - Ensure Firebase is properly initialized
   - Check Google Services configuration files
   - Verify app is not in simulator (iOS APNs requires device)

2. **Permissions denied**
   - Check if user previously denied permissions
   - Guide user to device settings to re-enable

3. **Background messages not working**
   - Ensure background handler is registered in main()
   - Check that handler function is top-level with @pragma annotation

4. **iOS notifications not showing**
   - Verify APNs certificates in Firebase Console
   - Check UNUserNotificationCenter delegate setup
   - Ensure foreground presentation options are set

5. **Android notifications not showing**
   - Verify notification channels are created
   - Check Android manifest configuration
   - Ensure target SDK version compatibility

### Debug Commands
```bash
# Check Firebase configuration
flutter packages get
flutter build ios --debug

# Test on device (required for push notifications)
flutter run --release -d [device_id]

# Check logs
flutter logs
```

## Security Considerations

1. **Token Security**: FCM tokens are not sensitive but should be refreshed regularly
2. **Server Validation**: Always validate notification requests on your server
3. **User Privacy**: Only send relevant notifications based on user preferences
4. **Rate Limiting**: Implement server-side rate limiting to prevent spam

## Performance

- Service is lightweight and initializes quickly
- Token refresh is handled automatically
- Background message handling is optimized
- Local notifications (Android) use minimal resources

## Maintenance

### Regular Tasks
1. Monitor token refresh rates
2. Update Firebase SDK versions quarterly
3. Test on new iOS/Android versions
4. Review notification analytics in Firebase Console

### Migration Notes
- This implementation replaces any existing notification systems
- Existing user notification preferences should be migrated
- Server-side token storage may need updates

## Support

For issues with this implementation:
1. Check Flutter/Firebase documentation
2. Verify device-specific testing (simulators have limitations)
3. Review Firebase Console for delivery metrics
4. Test with minimal payload first, then add complexity

---

*Implementation completed for Hands app - iOS 17+ and Android 15 (API 34) compatible*
