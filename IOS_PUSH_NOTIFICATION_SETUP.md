# iOS Push Notification Setup - Complete

## Status: ✅ CONFIGURED

### What Was Fixed

The iOS app was missing the proper Xcode project configuration to link the entitlements files, which meant Push Notifications capability wasn't being recognized by Xcode.

### Changes Made

**File: `ios/Runner.xcodeproj/project.pbxproj`**

Added `CODE_SIGN_ENTITLEMENTS` to all three build configurations:

1. **Debug Configuration**: 
   ```
   CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
   ```
   - Uses `aps-environment = development`
   - For local development and TestFlight builds

2. **Release Configuration**:
   ```
   CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;
   ```
   - Uses `aps-environment = production`
   - For App Store builds

3. **Profile Configuration**:
   ```
   CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease.entitlements;
   ```
   - Uses `aps-environment = production`
   - For profiling/performance testing

### Entitlements Files (Already Existed)

**Runner/Runner.entitlements** (Development/Debug):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>aps-environment</key>
  <string>development</string>
  
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>webcredentials:plan-with-hands.web.app</string>
  </array>
</dict>
</plist>
```

**Runner/RunnerRelease.entitlements** (Production/Release):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>aps-environment</key>
  <string>production</string>
  
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>webcredentials:plan-with-hands.web.app</string>
  </array>
</dict>
</plist>
```

## Verification Steps

### 1. In Xcode
1. **Close Xcode completely** (if open)
2. **Reopen workspace**: `open ios/Runner.xcworkspace`
3. **Select Runner target** in the project navigator
4. **Click "Signing & Capabilities" tab**
5. **You should now see**:
   - ✅ "Signing" section with your team and certificate
   - ✅ "Push Notifications" capability listed below
   - ✅ If not visible, click "+ Capability" and it should already be enabled

### 2. Build Configurations Check
In Xcode, select Runner target → Build Settings → search for "entitlements":
- **Debug**: Should show `Runner/Runner.entitlements`
- **Release**: Should show `Runner/RunnerRelease.entitlements`
- **Profile**: Should show `Runner/RunnerRelease.entitlements`

### 3. Test Push Notifications

#### Local Testing (Development)
```bash
flutter run
```
- App should request notification permissions on first launch
- Check device Settings → Plan with Hands → Notifications (should be enabled)

#### Firebase Console Test
1. Go to Firebase Console → Cloud Messaging
2. Send a test notification to your device token
3. Should receive notification even when app is in background

#### App Test
1. In app: Admin → Send Notification
2. Send to "All Users" or specific group
3. Should receive push notification immediately

## Complete Push Notification Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. User Action (Admin sends notification)              │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Flutter App writes to notificationOutbox            │
│    (notification_controller.dart)                       │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Cloud Function Trigger                              │
│    (onNotificationOutboxCreated)                        │
│    - Fetches FCM tokens                                │
│    - Sends FCM messages with APNS payload              │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 4. FCM sends to APNS (Apple Push Notification Service) │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 5. iOS Device receives notification                    │
│    ✅ Shows banner/alert                                │
│    ✅ Plays sound                                        │
│    ✅ Updates badge                                      │
└─────────────────────────────────────────────────────────┘
```

## Requirements Checklist

### Backend (Firebase Functions)
- ✅ `onNotificationOutboxCreated` deployed with APNS payload
- ✅ `scheduledDailySummary` includes FCM sending with APNS payload
- ✅ Functions successfully sending (logs show "2 successful, 0 failed")

### iOS App Configuration
- ✅ `Runner.entitlements` exists with `aps-environment: development`
- ✅ `RunnerRelease.entitlements` exists with `aps-environment: production`
- ✅ `project.pbxproj` references entitlements files in all configurations
- ✅ Firebase SDK initialized (firebase_messaging package)
- ✅ Bundle ID matches Firebase project: `com.planwithhands.hands`

### Apple Developer Account
- ✅ App ID has Push Notifications enabled
- ✅ Development certificate with Push Notifications
- ✅ Distribution certificate with Push Notifications
- ✅ APNs Auth Key uploaded to Firebase Console (or APNs certificates)

### Device/User Permissions
- ⚠️ User must grant notification permissions (iOS prompts on first launch)
- ⚠️ Device must be registered with FCM (token saved to Firestore)
- ⚠️ Device must have internet connection

## Troubleshooting

### "No Push Notifications capability in Xcode"
**Solution**: Close and reopen Xcode after updating `project.pbxproj`

### "Notifications not appearing on device"
1. Check Xcode logs when running from Xcode
2. Verify notification permissions: Settings → Plan with Hands → Notifications
3. Check if FCM token is saved in Firestore: `users/{userId}/deviceTokens`
4. Check Firebase Functions logs for send errors

### "Successfully sent but not received"
- Ensure using correct APNs environment (development vs production)
- Development builds require `aps-environment: development`
- App Store builds require `aps-environment: production`
- TestFlight builds can use either, but development is safer

### "Invalid APNs credentials"
- Verify APNs Auth Key is uploaded to Firebase Console
- Check that Auth Key is not expired
- Ensure Key ID, Team ID are correct in Firebase

## Next Steps for App Store Release

1. **Archive the app** with Release configuration
   - Xcode → Product → Archive
   - Will use `RunnerRelease.entitlements` with `production` environment

2. **Upload to App Store Connect**
   - Xcode Organizer → Distribute App

3. **Submit for Review**
   - Push Notifications capability will be included in the build

4. **Production Testing**
   - After App Store approval, download from TestFlight or App Store
   - Send test notification
   - Verify production push works

## Important Notes

1. **Development vs Production APNS**:
   - Firebase automatically detects which environment to use based on the app's provisioning profile
   - Development builds → APNs sandbox
   - Production builds → APNs production

2. **Badge Numbers**:
   - Currently hardcoded to `badge: 1` in functions
   - Consider implementing proper badge counting in the future

3. **Notification Sounds**:
   - Currently using `sound: "default"`
   - Can add custom notification sounds to Xcode project if needed

4. **Rich Notifications**:
   - Can enhance with images, action buttons, categories
   - Requires Notification Service Extension in iOS project

## Status: October 16, 2025

✅ **All components configured and deployed**
- Backend functions include APNS payloads
- iOS project properly linked to entitlements
- Logs confirm successful FCM sends
- Ready for production App Store build
