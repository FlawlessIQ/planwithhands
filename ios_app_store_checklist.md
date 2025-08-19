# iOS App Store Submission Checklist

## 🚨 Critical Fixes Needed

### 1. Bundle Identifier & App Identity
- [ ] **URGENT**: Change bundle identifier from `com.example.handsClean` to your unique ID
  - Recommended: `com.planwithhands.app` or `com.yourcompany.hands`
  - Update in: `ios/Runner.xcodeproj/project.pbxproj`
- [ ] Update app display name from "Hands Clean" to final name in `Info.plist`
- [ ] Update `CFBundleName` in `Info.plist`

### 2. Apple Developer Account Setup
- [ ] **REQUIRED**: Purchase Apple Developer Program membership ($99/year)
- [ ] Add your Team ID to Xcode project settings
- [ ] Create certificates and provisioning profiles
- [ ] Set up App Store Connect app listing

### 3. Version and Build Numbers
- [ ] Set proper semantic version (currently 0.4.2+10)
- [ ] For App Store: consider starting with 1.0.0+1
- [ ] Update in `pubspec.yaml`

## 📱 iOS Configuration

### Info.plist Requirements
- [x] Permission descriptions (Camera, Photo Library, Calendar) ✅
- [ ] Add missing permissions if needed:
  - [ ] `NSLocationWhenInUseUsageDescription` (if using location)
  - [ ] `NSUserNotificationUsageDescription` (for push notifications)
- [ ] Add App Transport Security settings if needed
- [ ] Configure supported device orientations

### App Icons
- [x] Basic app icons present ✅
- [ ] Verify all required sizes are properly generated:
  - [ ] 1024x1024 (App Store)
  - [ ] 180x180 (iPhone 6 Plus, 6s Plus, 7 Plus, 8 Plus)
  - [ ] 120x120 (iPhone 6, 6s, 7, 8, SE)
  - [ ] iPad sizes if supporting iPad
- [ ] Ensure icons follow Apple Human Interface Guidelines

### Launch Screen
- [x] LaunchScreen.storyboard exists ✅
- [ ] Verify launch screen displays correctly on all device sizes
- [ ] Ensure launch screen matches your app's first screen

## 🔐 Code Signing & Certificates

### Apple Developer Account Setup
- [ ] Create iOS Distribution Certificate
- [ ] Create App Store Provisioning Profile
- [ ] Configure automatic signing in Xcode or manual signing
- [ ] Test build with distribution certificate

### Entitlements (if needed)
- [ ] Push Notifications entitlement (you have Firebase messaging)
- [ ] Associated Domains (if using universal links)
- [ ] App Groups (if sharing data between apps)

## 📋 App Store Connect

### App Information
- [ ] Create app in App Store Connect
- [ ] App name (must be unique on App Store)
- [ ] App description (detailed, keyword-rich)
- [ ] Keywords for search optimization
- [ ] App category (Business/Productivity)
- [ ] Content rating questionnaire

### App Store Assets
- [ ] App Store icon (1024x1024)
- [ ] Screenshots for all supported devices:
  - [ ] iPhone 6.7" (iPhone 14 Pro Max, 15 Pro Max)
  - [ ] iPhone 6.1" (iPhone 14, 15)
  - [ ] iPhone 5.5" (iPhone 8 Plus)
  - [ ] iPad Pro (if supporting iPad)
- [ ] App preview videos (optional but recommended)

### App Store Metadata
- [ ] App description (4000 character limit)
- [ ] Keywords (100 character limit)
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] Privacy Policy URL (REQUIRED for apps that collect data)

## 🔒 Privacy & Compliance

### Privacy Requirements (CRITICAL)
- [ ] **Create Privacy Policy** (required - you collect user data)
- [ ] Complete App Privacy questionnaire in App Store Connect
- [ ] Data collection disclosure:
  - [ ] User accounts and authentication data
  - [ ] Contact information (email, name)
  - [ ] Work scheduling data
  - [ ] Photos (for task completion)
  - [ ] Calendar access
  - [ ] Push notification preferences

### Export Compliance
- [ ] Determine if your app uses encryption
- [ ] Complete export compliance questionnaire
- [ ] Most apps: "No" unless using additional encryption beyond HTTPS

## 🧪 Testing & Quality Assurance

### TestFlight Beta Testing (Recommended)
- [ ] Upload beta build to TestFlight
- [ ] Test with real users
- [ ] Test all features on different devices
- [ ] Test payment flow thoroughly
- [ ] Test push notifications

### Device Testing
- [ ] Test on physical iPhone devices (not just simulator)
- [ ] Test on different screen sizes
- [ ] Test on oldest supported iOS version
- [ ] Test in different orientations
- [ ] Test with low storage/memory conditions

### App Store Review Guidelines
- [ ] Review Apple's App Store Review Guidelines
- [ ] Ensure app doesn't violate any guidelines
- [ ] Test all user flows work correctly
- [ ] Ensure no placeholder content
- [ ] Test offline behavior
- [ ] Verify all buttons/features work

## 💳 Business Model & Payments

### Stripe Integration
- [x] Stripe payment integration ✅
- [ ] Ensure compliance with App Store payment guidelines
- [ ] If selling digital goods/services, may need Apple In-App Purchases
- [ ] For physical goods/services (like your scheduling app), Stripe is OK

### Subscription Management
- [ ] Clear cancellation policy
- [ ] User can manage subscription in app
- [ ] Terms of service
- [ ] Refund policy

## 🚀 Build & Submission

### Release Build
- [ ] Create release build: `flutter build ios --release`
- [ ] Test release build on device
- [ ] Verify all Firebase configurations work in release
- [ ] Test performance in release mode

### Final Submission
- [ ] Archive app in Xcode
- [ ] Upload to App Store Connect
- [ ] Complete all metadata
- [ ] Submit for review
- [ ] Monitor review status

## 📄 Required Documents/Pages

### Website Requirements
- [ ] **Privacy Policy** (hosted on your website)
- [ ] **Terms of Service**
- [ ] **Support page** with contact information
- [ ] App description page (optional but recommended)

### Sample Privacy Policy Sections Needed
- Data collection (user accounts, photos, calendar access)
- How data is used (scheduling, task management)
- Data sharing (mention Stripe for payments, Firebase for infrastructure)
- Data retention and deletion
- User rights and contact information

## ⚡ Performance & Technical

### App Performance
- [ ] App launches in under 20 seconds
- [ ] Responsive on all supported devices
- [ ] No crashes or major bugs
- [ ] Proper memory management
- [ ] Efficient network usage

### iOS Version Support
- [ ] Set minimum iOS version (currently supporting iOS 11+)
- [ ] Test on minimum supported version
- [ ] Consider modern iOS features for better user experience

## 🎯 Marketing & Launch

### Pre-Launch
- [ ] App Store Optimization (ASO) research
- [ ] Keyword research for app store search
- [ ] Plan launch timing
- [ ] Prepare press kit/materials

### Post-Launch
- [ ] Monitor reviews and ratings
- [ ] Plan for user feedback and updates
- [ ] Analytics and crash reporting setup (Firebase Crashlytics ✅)

---

## 🔧 Quick Start Commands

1. **Update Bundle Identifier**:
   ```bash
   # Open Xcode project
   open ios/Runner.xcworkspace
   # Update bundle identifier in project settings
   ```

2. **Build for Release**:
   ```bash
   flutter build ios --release
   ```

3. **Generate App Icons** (if needed):
   ```bash
   # Use online tools or design software to create all required sizes
   # Place in ios/Runner/Assets.xcassets/AppIcon.appiconset/
   ```

4. **Test Release Build**:
   ```bash
   flutter install --release
   ```

## ⚠️ Common Rejection Reasons to Avoid

- Placeholder content or "lorem ipsum" text
- Non-functional buttons or features
- App crashes or major bugs
- Missing privacy policy
- Incorrect app information or screenshots
- Using placeholder bundle identifier (com.example.*)
- Incomplete features or "coming soon" sections

---

**Estimated Timeline**: 2-4 weeks for first-time submission (including Apple Developer account setup, testing, and review process)
