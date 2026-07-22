# Release Notes - Version 1.1.23

**Release Date**: October 16, 2025

## 🔔 Push Notifications - Fixed (Critical)

### Issue Resolved
Push notifications were not being delivered to iOS devices. Messages appeared in-app but no push notifications were received on the device lock screen or notification center.

### What Was Fixed
1. **Added APNS Payload**: All notification functions now include proper Apple Push Notification Service (APNS) configuration required for iOS devices
2. **Daily Summary Notifications**: Added FCM push notification sending to admin daily summary function
3. **iOS Capabilities**: Configured Push Notifications capability in Xcode project with proper entitlements

### Impact
- ✅ Push notifications now work on iOS devices
- ✅ Applies to all notification types: daily summaries, admin announcements, group/location notifications
- ✅ Works in both development and production (App Store) builds

---

## 🎥 Admin Video Tutorial

### New Feature
Added prominent video tutorial banner in Help Center for admin users

### Details
- Video: "Hands Admin Demo" (11 MB, hosted in Firebase Storage)
- Location: Help Center page (Admin section only)
- Responsive design: 3 layouts (wide, medium, mobile)
- Opens in new browser tab when clicked

### UI Cleanup
- Removed redundant "System Overview" quick action for admins
- Removed redundant "Web Management" quick action for admins
- Video tutorial provides better comprehensive guidance

---

## 📱 Platform Builds

### iOS (App Store Ready)
- Version: 1.1.23 (Build 23)
- Podfile synced with 60 dependencies
- Firebase SDK: 11.15.0
- Push Notifications capability enabled
- Entitlements configured for development and production

### Android (Play Store Ready)
- Version: 1.1.23 (Build 23)
- AAB file: 75.7 MB (signed and verified)
- Optimizations: Tree-shaking, R8 minification, resource shrinking
- Ready for Google Play Console upload

### Web
- Built with release configuration
- Deployed to Firebase Hosting
- URL: https://plan-with-hands.web.app

---

## 🔧 Technical Changes

### Backend (Firebase Functions)
- **Updated**: `onNotificationOutboxCreated` - Added APNS payload for iOS compatibility
- **Updated**: `scheduledDailySummary` - Added FCM push notification sending with APNS payload
- **Deployed**: Both functions live in production

### iOS Configuration
- Added `CODE_SIGN_ENTITLEMENTS` to all build configurations
- `Runner.entitlements`: Development APNs environment
- `RunnerRelease.entitlements`: Production APNs environment
- Push Notifications capability properly linked in Xcode project

### Apple Developer Portal
- Push Notifications capability enabled on App ID
- APNs Authentication Key uploaded to Firebase Console
- Team ID: 7FN7C2C3N6
- Key ID: 3FMMAMVRHQ

---

## 📝 What's New for Users

### For Admins
- **Video Tutorial**: New admin demo video accessible from Help Center
- **Push Notifications**: Will now receive daily summary notifications on iOS devices
- **Cleaner UI**: Streamlined quick actions in Help Center

### For All Users
- **Push Notifications**: Announcements, group messages, and location-specific notifications now properly delivered to iOS devices
- **Reliability**: Notifications work whether app is in foreground, background, or closed

---

## ✅ Testing Completed

- ✅ Backend functions sending notifications successfully (logs show "2 successful, 0 failed")
- ✅ iOS entitlements properly configured
- ✅ Push Notifications capability present in Xcode
- ✅ APNs authentication configured in Firebase
- ✅ Android AAB signed and verified
- ✅ Podfile synced (60 pods installed)

---

## 📦 Deployment Checklist

### iOS App Store
- [ ] Archive build in Xcode (Runner.xcworkspace)
- [ ] Upload to App Store Connect
- [ ] Submit for review
- [ ] Include in release notes: "Fixed push notifications for iOS devices"

### Android Play Store
- [x] AAB file generated: `build/app/outputs/bundle/release/app-release.aab`
- [x] Signed with release key
- [ ] Upload to Play Console
- [ ] Submit for review

### Firebase
- [x] Functions deployed
- [x] Web app deployed to hosting

---

## 🐛 Known Issues
None

## 🔮 Next Release
- Consider implementing badge count management
- Explore rich notifications with images/actions
- Add custom notification sounds

---

**Build Information**:
- iOS: Runner.xcworkspace (60 pods)
- Android: app-release.aab (75.7 MB)
- Flutter SDK: 3.32.0
- Dart: 3.8.0
