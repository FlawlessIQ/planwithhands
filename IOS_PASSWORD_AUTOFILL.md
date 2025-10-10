# iOS Password AutoFill Implementation Guide

## Overview
This document explains the iOS Password AutoFill implementation for the Plan with Hands app, enabling seamless password management integration with iOS Keychain and iCloud Keychain.

## Problem Statement
Previously, the app had the following issues with iOS password management:
1. ❌ Passwords could be saved manually but weren't automatically associated with the app
2. ❌ Users had to manually search in the Passwords app to find credentials
3. ❌ iOS didn't recognize when users were in the "Plan with Hands" app
4. ❌ No automatic prompt to save password on first login
5. ❌ No QuickType bar password suggestions above the keyboard

## Solution Implementation

### 1. Associated Domains (webcredentials)
**Purpose:** Links the iOS app with the web domain to enable password sharing between platforms.

**Files Modified:**
- `ios/Runner/Runner.entitlements`
- `ios/Runner/RunnerRelease.entitlements`

**Configuration:**
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>webcredentials:plan-with-hands.web.app</string>
</array>
```

**What this does:**
- Tells iOS that this app (bundle ID: `com.planwithhands.hands`) is associated with `plan-with-hands.web.app`
- Enables password sharing between the iOS app and web app
- Required for iOS to recognize the app when suggesting saved credentials

### 2. Apple App Site Association File
**Purpose:** Verifies the association from the web domain side, proving the app owns this domain.

**File Created:**
- `web/.well-known/apple-app-site-association`

**Content:**
```json
{
  "webcredentials": {
    "apps": [
      "M7X5RW4GVL.com.planwithhands.hands"
    ]
  }
}
```

**Format:** `<Team ID>.<Bundle ID>`
- Team ID: `M7X5RW4GVL` (from Apple Developer account)
- Bundle ID: `com.planwithhands.hands`

**Hosting Requirements:**
- Must be served at: `https://plan-with-hands.web.app/.well-known/apple-app-site-association`
- Content-Type: `application/json`
- No file extension (the file is literally named `apple-app-site-association` with no `.json`)
- Must be accessible over HTTPS
- Should be served from root domain (not subdirectory)

**Deployment:**
The file is:
1. Created in `web/.well-known/` directory
2. Copied to `build/web/.well-known/` during build process (via `copy_well_known.sh`)
3. Deployed to Firebase Hosting
4. Configured in `firebase.json` with proper headers

### 3. TextField Configuration (Flutter)
**Purpose:** Properly configure text fields to participate in iOS AutoFill.

**File Modified:**
- `lib/features/auth/pages/login_page.dart`

**Key Configuration:**

#### AutofillGroup Wrapper
```dart
AutofillGroup(
  child: Column(
    children: [
      // Email field
      // Password field
    ],
  ),
)
```
**What this does:**
- Groups related autofill fields together
- Tells iOS these fields are part of a single login form
- Required for iOS to offer to save credentials

#### Email Field
```dart
HandsTextFormField(
  controller: emailController,
  autofillHints: const [AutofillHints.username],
  keyboardType: TextInputType.emailAddress,
  textInputAction: TextInputAction.next,
  // ... other configuration
)
```
**Important:**
- Use `AutofillHints.username` (not `.email`) for better iOS compatibility
- This hint tells iOS this field contains the username/email for login

#### Password Field
```dart
HandsTextFormField(
  controller: passwordController,
  autofillHints: const [AutofillHints.password],
  obscureText: !isPasswordVisible.value,
  textInputAction: TextInputAction.done,
  textCapitalization: TextCapitalization.none,
  // ... other configuration
)
```
**Important:**
- `AutofillHints.password` identifies this as a password field
- `textCapitalization: TextCapitalization.none` prevents auto-capitalization
- `obscureText: true` maintains password security

#### Completion Signal
```dart
// After successful login:
TextInput.finishAutofillContext();
```
**What this does:**
- Signals to iOS that the login was successful
- Triggers the "Save Password?" prompt
- Commits any pending autofill data
- **Critical:** This MUST be called after successful authentication

### 4. Firebase Hosting Configuration
**File Modified:**
- `firebase.json`

**Configuration Added:**
```json
{
  "source": "/.well-known/apple-app-site-association",
  "headers": [
    { "key": "Content-Type", "value": "application/json" },
    { "key": "Cache-Control", "value": "public,max-age=3600" }
  ]
}
```
**Note:** Removed `.well-known` from ignore list to allow it to be deployed.

### 5. Build Script
**File Created:**
- `copy_well_known.sh`

**Purpose:** 
Ensures `.well-known` directory is copied to `build/web/` during the build process, since Flutter build doesn't automatically copy hidden directories.

**Usage:**
```bash
# Run before deploying to Firebase
./copy_well_known.sh
```

## Verification Steps

### 1. Verify Associated Domains in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Verify "Associated Domains" capability is present
4. Verify `webcredentials:plan-with-hands.web.app` is listed

### 2. Verify Apple App Site Association File
**Test the file is accessible:**
```bash
curl -v https://plan-with-hands.web.app/.well-known/apple-app-site-association
```

**Should return:**
- HTTP 200 status
- Content-Type: application/json
- The JSON content with your Team ID and Bundle ID

**Apple's Validator:**
- Visit: https://search.developer.apple.com/appsearch-validation-tool/
- Enter: `plan-with-hands.web.app`
- Should show successful validation

### 3. Test on Device
**First Time Setup:**
1. Delete the app if previously installed
2. Install fresh build from Xcode or TestFlight
3. Open Settings → Passwords → Password Options
4. Verify "AutoFill Passwords" is enabled
5. Verify "iCloud Keychain" or app is selected

**Testing Login:**
1. Open the app
2. Navigate to login screen
3. Tap email field
4. Should see QuickType bar above keyboard with:
   - 🔑 Key icon (if credentials exist)
   - Suggested credentials from iCloud Keychain
   - "Passwords..." option
5. If no saved credentials:
   - Enter email and password manually
   - Submit login
   - Should see "Save Password for plan-with-hands.web.app?" prompt
6. Save the password
7. Log out and return to login screen
8. Tap email field
9. Should now see saved credentials in QuickType bar

### 4. Test Password Association
**Verify app recognition:**
1. Open Settings → Passwords
2. Search for "plan with hands" or "plan-with-hands.web.app"
3. Tap the saved credential
4. Under "Websites & Apps", should show:
   - 🌐 plan-with-hands.web.app
   - 📱 Plan with Hands (your app)

**This confirms iOS recognizes the app-website association.**

## Troubleshooting

### Password Suggestions Not Appearing
**Possible causes:**
1. Associated Domains not properly configured in entitlements
2. Apple App Site Association file not accessible or malformed
3. App not signed with correct Team ID
4. iOS hasn't fetched the association file yet (can take up to 24 hours)
5. AutoFill not enabled in iOS Settings

**Solutions:**
- Verify all configuration steps above
- Rebuild and reinstall the app completely
- Wait 24-48 hours for iOS to cache the association
- Test in production build, not debug build
- Check Apple's validation tool

### "Save Password" Prompt Not Showing
**Possible causes:**
1. `TextInput.finishAutofillContext()` not called after successful login
2. AutofillGroup not wrapping the form
3. Autofill hints missing or incorrect
4. User declined prompt previously (iOS remembers)

**Solutions:**
- Verify `finishAutofillContext()` is called after successful authentication
- Check AutofillGroup is present
- Delete app and reinstall to reset prompt history
- Verify autofillHints are set to `[AutofillHints.username]` and `[AutofillHints.password]`

### App Not Recognized in Password Manager
**Possible causes:**
1. Team ID incorrect in apple-app-site-association
2. Bundle ID mismatch
3. File not accessible at correct URL
4. Content-Type header incorrect

**Solutions:**
- Verify Team ID: Check in Apple Developer account under Membership
- Verify Bundle ID matches Xcode project: `com.planwithhands.hands`
- Test file accessibility with curl command above
- Check Firebase Hosting headers configuration

### iOS Says "Unable to Verify App"
**Possible causes:**
1. apple-app-site-association file has wrong format
2. File not served with application/json content type
3. HTTPS certificate issues

**Solutions:**
- Validate JSON format (use jsonlint.com)
- Check Content-Type header in Firebase configuration
- Verify Firebase Hosting SSL is working correctly

## Important Notes

### Team ID
- **CRITICAL:** The Team ID (`M7X5RW4GVL`) must match your Apple Developer account
- Find your Team ID:
  - Apple Developer → Membership → Team ID
  - Xcode → Project Settings → Signing & Capabilities → Team dropdown
- If you change teams, you MUST update the apple-app-site-association file

### Bundle ID
- Current: `com.planwithhands.hands`
- If this changes, update:
  1. Xcode project bundle identifier
  2. apple-app-site-association file
  3. Rebuild and redeploy both app and web

### Domain
- Current: `plan-with-hands.web.app`
- If you add a custom domain, you must:
  1. Add new webcredentials entry to entitlements
  2. Host apple-app-site-association file on new domain
  3. Rebuild app

### iOS Version Requirements
- Associated Domains: iOS 9.0+
- Password AutoFill: iOS 11.0+
- AutofillGroup in Flutter: Works on all iOS versions Flutter supports

## Deployment Checklist

### Before Each iOS Release:
- [ ] Verify Runner.entitlements has Associated Domains
- [ ] Verify RunnerRelease.entitlements has Associated Domains
- [ ] Run `./copy_well_known.sh` before building
- [ ] Build Flutter web: `flutter build web --release`
- [ ] Deploy to Firebase: `firebase deploy --only hosting`
- [ ] Verify apple-app-site-association is accessible
- [ ] Build iOS app with proper signing
- [ ] Test on physical device
- [ ] Submit to TestFlight/App Store

### After Deployment:
- [ ] Test password save prompt on fresh install
- [ ] Test password suggestions on login screen
- [ ] Verify app appears in Settings → Passwords
- [ ] Check QuickType bar shows key icon

## References

- [Apple: Supporting Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Password AutoFill](https://developer.apple.com/documentation/security/password_autofill)
- [Flutter: AutofillGroup](https://api.flutter.dev/flutter/widgets/AutofillGroup-class.html)
- [Firebase Hosting Configuration](https://firebase.google.com/docs/hosting/full-config)

## Support

If password autofill still doesn't work after following all steps:
1. Verify device Settings → Passwords → AutoFill Passwords is ON
2. Check that iCloud Keychain is enabled (Settings → [Your Name] → iCloud → Passwords & Keychain)
3. Try logging in on the web app first to save credentials to iCloud Keychain
4. Wait 24-48 hours for iOS to fetch and cache the association file
5. Test on multiple devices to rule out device-specific issues
6. Check Xcode Console for any autofill-related errors or warnings

## Maintenance

### Regular Checks:
- Monthly: Verify apple-app-site-association file is still accessible
- After domain changes: Update entitlements and association file
- After bundle ID changes: Update association file and rebuild
- After Team ID changes: Update association file immediately

### Monitoring:
- Track analytics for password save prompt acceptance rate
- Monitor user feedback about login experience
- Test regularly on new iOS versions
- Keep Flutter and dependencies updated for latest autofill improvements
