# Password Autofill Setup Guide

## Overview
This guide explains how to complete the setup for native password autofill on both iOS and Android for the Plan with Hands app.

## ✅ What's Been Fixed

### iOS
1. **Entitlements Updated**: Associated domains properly configured in `Runner.entitlements` and `RunnerRelease.entitlements`
2. **AutofillHints Added**: Email field now includes both `AutofillHints.email` and `AutofillHints.username`
3. **Apple App Site Association**: Already configured at `web/.well-known/apple-app-site-association`
4. **TextInput.finishAutofillContext()**: Called after successful login to trigger save prompt

### Android
1. **AutoVerify Intent Filter**: Added to `AndroidManifest.xml` for Digital Asset Links
2. **assetlinks.json**: Created template at `web/.well-known/assetlinks.json`
3. **AutofillHints**: Email field includes proper autofill hints

## 🔧 Additional Steps Required

### For iOS - Already Working!

The iOS configuration should work automatically. Test by:
1. Build and install app on iOS device
2. Log in with credentials
3. After successful login, iOS should prompt to save password
4. Next time you return to login, password should autofill

**If it's still not recognizing automatically:**
- Make sure you're testing on a **physical iOS device** (not simulator)
- Ensure the domain `plan-with-hands.web.app` is accessible
- Verify your Apple Developer Team ID is correct

### For Android - Requires SHA-256 Fingerprint

#### Step 1: Get Your App's SHA-256 Fingerprint

For **debug builds** (development):
```bash
cd android
./gradlew signingReport
```

Look for the SHA256 fingerprint under "Variant: debug" or "Variant: debugAndroidTest"

For **release builds** (production):
```bash
keytool -list -v -keystore android/hands-release-key.keystore -alias hands-key
```
Enter your keystore password when prompted.

#### Step 2: Update assetlinks.json

1. Copy the SHA-256 fingerprint (should be 64 characters with colons, like `AA:BB:CC:...`)
2. Remove all colons from the fingerprint
3. Open `web/.well-known/assetlinks.json`
4. Replace `"ADD_YOUR_SHA256_FINGERPRINT_HERE"` with your actual fingerprint

Example:
```json
{
  "sha256_cert_fingerprints": [
    "14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"
  ]
}
```

Becomes (remove colons):
```json
{
  "sha256_cert_fingerprints": [
    "146DE983C5730650D8EEB9952F34FC6416A08342E61DBEA88A0496B23FCF44E5"
  ]
}
```

**For both debug AND release**, add both fingerprints:
```json
{
  "sha256_cert_fingerprints": [
    "YOUR_DEBUG_FINGERPRINT_HERE",
    "YOUR_RELEASE_FINGERPRINT_HERE"
  ]
}
```

#### Step 3: Deploy assetlinks.json

The file needs to be accessible at:
```
https://plan-with-hands.web.app/.well-known/assetlinks.json
```

If using Firebase Hosting:
```bash
firebase deploy --only hosting
```

Make sure `.well-known` folder is not in `.gitignore` or `firebase.json` ignore patterns.

#### Step 4: Verify Digital Asset Links

After deploying, verify at:
```
https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://plan-with-hands.web.app&relation=delegate_permission/common.get_login_creds
```

Should return your app's package name and fingerprints.

#### Step 5: Test on Android

1. **Install the app** with the matching SHA-256 fingerprint (debug or release)
2. **Open Settings → Passwords** and ensure Google is the autofill service
3. **Log in** to the app with credentials
4. Android should prompt to save password
5. **Next login**, password should autofill automatically

## 🎯 How It Works

### iOS Password Autofill
1. App declares associated domain: `webcredentials:plan-with-hands.web.app`
2. iOS fetches `apple-app-site-association` from your domain
3. Verifies app's Bundle ID matches: `com.planwithhands.hands`
4. When user focuses on login fields with `AutofillHints`, iOS offers saved passwords
5. After login, `TextInput.finishAutofillContext()` triggers save prompt

### Android Password Autofill  
1. App declares intent filter with `autoVerify="true"` for domain
2. Android fetches `assetlinks.json` from your domain
3. Verifies app's package name and SHA-256 fingerprint match
4. When user focuses on fields with autofill hints, Android offers saved passwords
5. After login, `TextInput.finishAutofillContext()` triggers save prompt

## 🔍 Troubleshooting

### iOS Issues

**Password not autofilling:**
- Check Settings → Passwords → AutoFill Passwords is enabled
- Verify you have saved passwords for "plan-with-hands.web.app"
- Test on physical device (not simulator)
- Check Console.app for "Associated Domains" errors

**Not prompting to save:**
- Ensure `TextInput.finishAutofillContext()` is called after successful login (✅ already implemented)
- Check that AutofillGroup wraps both email and password fields (✅ already implemented)

### Android Issues

**Password not autofilling:**
- Verify assetlinks.json is accessible at correct URL
- Check SHA-256 fingerprint matches exactly (no colons, correct case)
- Ensure Google is set as autofill service: Settings → System → Languages & Input → Autofill Service
- Clear app data and re-install to force verification

**Digital Asset Links verification failing:**
- Check assetlinks.json is valid JSON
- Verify domain is accessible via HTTPS (not HTTP)
- Ensure no robots.txt blocking `.well-known` path
- Wait 24 hours for Google's cache to update

**Check verification status:**
```bash
adb shell pm get-app-links com.planwithhands.hands
```

Should show `verified` status for plan-with-hands.web.app

## 📱 Testing Checklist

### iOS
- [ ] Build app and install on physical iOS device
- [ ] Enable AutoFill in Settings → Passwords
- [ ] Log in with test credentials
- [ ] Verify iOS prompts to save password
- [ ] Clear app data and reinstall
- [ ] Verify saved password autofills on login screen

### Android
- [ ] Get SHA-256 fingerprint for debug build
- [ ] Update assetlinks.json with fingerprint
- [ ] Deploy assetlinks.json to hosting
- [ ] Verify Digital Asset Links API
- [ ] Install app on Android device
- [ ] Enable Google Autofill in Settings
- [ ] Log in with test credentials
- [ ] Verify Android prompts to save password
- [ ] Clear app data and reinstall
- [ ] Verify saved password autofills on login screen

## 📚 References

- [iOS Password AutoFill](https://developer.apple.com/documentation/security/password_autofill/)
- [Android Autofill Framework](https://developer.android.com/guide/topics/text/autofill)
- [Digital Asset Links](https://developers.google.com/digital-asset-links/v1/getting-started)
- [Flutter AutofillGroup](https://api.flutter.dev/flutter/widgets/AutofillGroup-class.html)

## 🎉 Expected Result

### iOS
- When user taps email field, iOS shows "Passwords" option above keyboard
- Tapping it shows saved passwords for the app
- Selecting a password fills both email and password fields
- After successful login, iOS prompts: "Save Password for plan-with-hands.web.app?"

### Android  
- When user taps email field, Android shows saved passwords in dropdown
- Selecting a password fills both email and password fields
- After successful login, Android prompts: "Save password?"
- Password is saved in Google Password Manager

---

**Status**: ✅ iOS configuration complete, Android requires SHA-256 fingerprint setup

**Last Updated**: October 15, 2025
