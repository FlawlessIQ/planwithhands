# App Store Build - Version 1.1.23 (Build 23)

**Date:** October 16, 2025  
**Status:** ✅ Ready for Xcode Build

## Version Information

- **Version:** 1.1.23
- **Build Number:** 23
- **Location:** `pubspec.yaml` line 20: `version: 1.1.23+23`

## Pre-Build Checklist

### ✅ Completed Steps

1. **Version Updated**
   - pubspec.yaml: `version: 1.1.23+23`
   - iOS Info.plist: Uses `$(FLUTTER_BUILD_NAME)` and `$(FLUTTER_BUILD_NUMBER)` (automatic)

2. **CocoaPods Synced**
   - Ran: `pod install --repo-update`
   - Result: 60 total pods installed
   - Firebase SDK: 11.15.0
   - All dependencies up to date

3. **Recent Features Deployed**
   - ✅ Admin Tutorial Video in Help Center
   - ✅ Video in Welcome Organization Dialog
   - ✅ Removed redundant Quick Actions (System Overview, Web Management)
   - ✅ Green checklist completion indicator
   - ✅ Daily summary improvements

4. **Web Version Deployed**
   - Built: `flutter build web --release`
   - Deployed: `firebase deploy --only hosting`
   - Live at: https://plan-with-hands.web.app

## Build Instructions for Xcode

### Step 1: Clean Build
```bash
cd "/Users/conorlawless/Development/Hands app"
flutter clean
flutter pub get
```

### Step 2: Build for iOS
```bash
flutter build ios --release --no-codesign
```

### Step 3: Open in Xcode
```bash
open ios/Runner.xcworkspace
```

### Step 4: Xcode Settings
1. **Select Target:** Runner
2. **Signing & Capabilities:**
   - Team: FlawlessIQ LLC (or your team)
   - Bundle Identifier: `com.handsapp.hands_app`
   - Automatically manage signing: ✓

3. **General Tab - Identity:**
   - Display Name: `Plan with Hands`
   - Version: `1.1.23` (auto from pubspec.yaml)
   - Build: `23` (auto from pubspec.yaml)

4. **Select Device/Destination:**
   - Choose "Any iOS Device (arm64)" for App Store
   - OR choose your connected device for TestFlight

### Step 5: Archive & Upload
1. **Product → Archive** (⌘B first to ensure clean build)
2. Wait for archive to complete (~5-10 minutes)
3. **Window → Organizer** to view archives
4. Select your archive → **Distribute App**
5. Choose **App Store Connect**
6. Follow prompts to upload

## What's New in 1.1.23

### Admin Features
- **Admin Tutorial Video**: Prominent video guide in Help Center for admins
- **Streamlined Help Center**: Removed redundant quick actions, focused on video tutorial
- **Welcome Dialog Enhancement**: Video tutorial link in new organization setup

### UI/UX Improvements
- **Green Completion Indicator**: Checklist headers turn green when all tasks complete
- **Cleaner Interface**: Simplified admin Help Center layout

### Technical
- Firebase SDK 11.15.0
- iOS 13.0+ deployment target
- All pods updated and synced

## Post-Upload Steps

1. **App Store Connect:**
   - Go to https://appstoreconnect.apple.com
   - Select "Plan with Hands"
   - Navigate to TestFlight or App Store section

2. **TestFlight (Optional):**
   - Add internal/external testers
   - Write "What's New" notes
   - Submit for review

3. **App Store Submission:**
   - Complete app information
   - Add screenshots if needed
   - Set pricing/availability
   - Submit for review

## Notes

- Build time: ~5-10 minutes for archive
- Upload time: ~5-15 minutes depending on connection
- Review time: Typically 24-48 hours

## Troubleshooting

### Common Issues

1. **"No provisioning profiles found"**
   - Solution: Xcode → Preferences → Accounts → Download Manual Profiles

2. **"Code signing error"**
   - Solution: Select your team in Signing & Capabilities

3. **"Build failed"**
   - Solution: Run `flutter clean && flutter pub get` and try again

4. **"Missing entitlements"**
   - Solution: Check Signing & Capabilities tab has all required capabilities

## Firebase Configuration

- ✅ GoogleService-Info.plist in place
- ✅ Push notifications configured
- ✅ Cloud Firestore enabled
- ✅ Cloud Functions deployed
- ✅ Firebase Storage configured

## Critical Files Verified

- ✅ `ios/Podfile` - iOS 13.0 minimum, optimized settings
- ✅ `ios/Runner/Info.plist` - Version variables configured
- ✅ `pubspec.yaml` - Version 1.1.23+23
- ✅ `ios/Runner.xcworkspace` - Ready to open in Xcode

---

**Ready to build!** 🚀

Open Xcode and follow the build instructions above.
