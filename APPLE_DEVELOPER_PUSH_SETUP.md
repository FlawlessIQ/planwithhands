# Apple Developer Push Notifications Setup Guide

## Current Status: Configuration Needed

### Xcode Setup
✅ **COMPLETE** - Entitlements properly configured in Xcode project

### Apple Developer Portal Setup
⚠️ **NEEDS VERIFICATION** - Follow steps below

### Firebase Console Setup
⚠️ **NEEDS VERIFICATION** - APNs authentication must be configured

---

## Step-by-Step Apple Developer Configuration

### Step 1: Enable Push Notifications on App ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)

2. **Sign in** with your Apple Developer account

3. **Navigate to**: Certificates, Identifiers & Profiles → **Identifiers**

4. **Find your App ID**: Search for `com.planwithhands.hands` or "Plan with Hands"

5. **Click on the App ID** to view details

6. **Check the Capabilities list**:
   - Scroll to "Push Notifications"
   - ✅ Ensure it's **CHECKED/ENABLED**
   - If not checked:
     - Click "Edit" or the App ID name
     - Check "Push Notifications"
     - Click "Save"

7. **Note the warning**: After enabling, you'll see:
   > "Push Notifications: Configurable (Development and Production)"

---

### Step 2: Create APNs Authentication Key (RECOMMENDED)

This is the **easiest and most reliable** method for push notifications.

#### Create the Key

1. Go to [Keys Section](https://developer.apple.com/account/resources/authkeys/list)

2. Click the **"+" button** to create a new key

3. **Configure the key**:
   - **Key Name**: `Hands APNs Key` (or any descriptive name)
   - **Check**: ✅ Apple Push Notifications service (APNs)
   - Click "Continue"

4. **Review and Register**:
   - Verify the key name and service
   - Click "Register"

5. **Download the Key**:
   - ⚠️ **CRITICAL**: You can only download this ONCE
   - Click "Download" to get the `.p8` file
   - Save it securely (you'll need it for Firebase)
   - The filename will be: `AuthKey_XXXXXXXXXX.p8`

6. **Record Important Information**:
   ```
   Key ID: XXXXXXXXXX (shown on screen)
   Team ID: XXXXXXXXXX (top right of Apple Developer portal)
   ```
   - Write these down or save in a secure location

---

### Step 3: Upload APNs Key to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/project/plan-with-hands/settings/cloudmessaging)

2. **Navigate to Cloud Messaging**:
   - Click the ⚙️ Settings icon
   - Select "Project settings"
   - Click "Cloud Messaging" tab

3. **Find Apple app configuration section**:
   - Scroll to "Apple app configuration"
   - Find your iOS app: `com.planwithhands.hands`

4. **Upload APNs Authentication Key**:
   - Click "Upload" under "APNs Authentication Key"
   - Select your `.p8` file
   - Enter:
     - **Key ID**: (from Step 2, #6)
     - **Team ID**: (from Step 2, #6)
   - Click "Upload"

5. **Verify Upload**:
   - You should see: ✅ "APNs Authentication Key uploaded"
   - Status should show the Key ID

---

## Alternative: APNs Certificates (Old Method)

If you prefer certificates over authentication keys (not recommended):

### Create APNs Certificates

1. Go to [Certificates Section](https://developer.apple.com/account/resources/certificates/list)

2. Click "+" to create new certificate

3. **Development Certificate**:
   - Select "Apple Push Notification service SSL (Sandbox & Development)"
   - Choose your App ID: `com.planwithhands.hands`
   - Generate CSR (Certificate Signing Request):
     - Open "Keychain Access" on Mac
     - Menu: Keychain Access → Certificate Assistant → Request Certificate from CA
     - Enter email, common name, "Save to disk"
   - Upload CSR
   - Download certificate
   - Double-click to install in Keychain

4. **Production Certificate** (repeat for production):
   - Select "Apple Push Notification service SSL (Sandbox & Production)"
   - Same process as development

5. **Upload to Firebase**:
   - Export certificate from Keychain as `.p12`
   - Upload to Firebase Cloud Messaging settings

---

## Step 4: Regenerate Provisioning Profiles

After enabling Push Notifications or creating certificates, your provisioning profiles are now invalid.

### Automatic (Recommended)

1. Open Xcode
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. **Uncheck** "Automatically manage signing"
5. **Re-check** "Automatically manage signing"
6. Xcode will download/regenerate profiles with Push Notifications capability

### Manual

1. Go to [Profiles Section](https://developer.apple.com/account/resources/profiles/list)

2. **Delete old profiles** for your app:
   - iOS App Development
   - iOS App Store

3. **Create new Development Profile**:
   - Click "+"
   - Select "iOS App Development"
   - Choose App ID: `com.planwithhands.hands`
   - Select certificates (with Push Notifications)
   - Select devices
   - Name it and download

4. **Create new Distribution Profile**:
   - Click "+"
   - Select "App Store"
   - Choose App ID: `com.planwithhands.hands`
   - Select distribution certificate (with Push Notifications)
   - Name it and download

5. **Install Profiles**:
   - Double-click `.mobileprovision` files to install in Xcode

---

## Step 5: Verify in Xcode

1. **Open Xcode**: `open ios/Runner.xcworkspace`

2. **Select Runner target** → **Signing & Capabilities**

3. **Verify**:
   - ✅ Push Notifications capability is listed
   - ✅ No warnings about provisioning profiles
   - ✅ Signing certificate shows under "Signing (Debug/Release)"

4. **Build Settings Check**:
   - Select Runner target → Build Settings
   - Search for "CODE_SIGN_ENTITLEMENTS"
   - **Debug**: `Runner/Runner.entitlements`
   - **Release**: `Runner/RunnerRelease.entitlements`

---

## Step 6: Test Configuration

### Test 1: Build and Run
```bash
flutter run
```
- App should launch without signing errors
- Check logs for notification registration

### Test 2: Check FCM Token
When app launches, it should register for push notifications and save an FCM token to Firestore:
- Open Firebase Console → Firestore
- Navigate to: `users/{userId}/deviceTokens`
- Should see documents with `fcmToken` field

### Test 3: Send Test Notification
1. Open Firebase Console → Cloud Messaging
2. Click "Send your first message"
3. Enter test title/message
4. Click "Send test message"
5. Paste your device FCM token
6. Should receive notification on device

### Test 4: App Notification
1. In app: Admin → Send Notification
2. Enter title and message
3. Send to "All Users"
4. Should receive push notification

---

## Troubleshooting

### "No Push Notifications capability in Xcode"
**Solution**: 
- Verify App ID has Push Notifications enabled in Apple Developer Portal
- Regenerate provisioning profiles
- Re-enable automatic signing in Xcode

### "APNs delivery failed" in Firebase logs
**Solution**:
- Ensure APNs Authentication Key is uploaded to Firebase
- Verify Key ID and Team ID are correct
- Check that App ID matches Firebase project

### "Invalid provisioning profile"
**Solution**:
- Delete and regenerate provisioning profiles after enabling Push Notifications
- Use Xcode automatic signing to let it handle profile generation

### "Development vs Production environment mismatch"
**Solution**:
- Development builds use `aps-environment: development` (sandbox)
- Production/TestFlight/App Store use `aps-environment: production`
- Ensure entitlements file matches build configuration

### Token not saving to Firestore
**Solution**:
- Check app permissions: Settings → Plan with Hands → Notifications
- Verify `firebase_messaging` package is initialized in Flutter app
- Check Xcode logs for permission request and token generation

---

## Quick Checklist

Before submitting to App Store, verify:

- [ ] App ID has Push Notifications enabled
- [ ] APNs Authentication Key created and downloaded
- [ ] APNs Key uploaded to Firebase Console
- [ ] Entitlements files configured (`Runner.entitlements`, `RunnerRelease.entitlements`)
- [ ] Xcode project references entitlements files
- [ ] Provisioning profiles include Push Notifications capability
- [ ] Test notifications working in development
- [ ] Cloud Functions include APNS payload
- [ ] Firebase project has correct APNs configuration

---

## Important Notes

1. **APNs Key vs Certificates**:
   - **Key (Recommended)**: One key works for all apps, never expires, easier to manage
   - **Certificates**: Separate for dev/prod, expire yearly, more complex

2. **Environment Switching**:
   - Firebase automatically detects environment based on provisioning profile
   - Development builds → APNs Sandbox
   - Production builds → APNs Production

3. **Team ID Location**:
   - Top right corner of Apple Developer Portal
   - Also in App ID configuration page
   - Format: 10 characters (e.g., `7FN7C2C3N6`)

4. **Key ID Location**:
   - Shown after creating APNs Authentication Key
   - Also visible in Keys list in Apple Developer Portal
   - Format: 10 characters

---

## Resources

- [Apple Developer Portal](https://developer.apple.com/account/)
- [Firebase Console - Cloud Messaging](https://console.firebase.google.com/project/plan-with-hands/settings/cloudmessaging)
- [Apple Push Notification Guide](https://developer.apple.com/documentation/usernotifications)
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging/ios/client)

---

## Status: October 16, 2025

**Next Steps**:
1. ✅ Follow Step 1: Enable Push Notifications on App ID
2. ✅ Follow Step 2: Create APNs Authentication Key
3. ✅ Follow Step 3: Upload Key to Firebase Console
4. ✅ Follow Step 4: Regenerate Provisioning Profiles in Xcode

After completing these steps, push notifications will work on both development builds and App Store releases.
