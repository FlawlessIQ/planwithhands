# iOS Password Autofill - Troubleshooting Guide

## Current Status
✅ **Associated Domains configured** in entitlements
✅ **Apple App Site Association file** deployed
✅ **AutofillHints** properly set on text fields
⚠️ **Issue**: Must search for password instead of automatic recognition

## Why iOS Requires Manual Search

When iOS requires you to search for passwords instead of automatically recognizing the app, it usually means one of these issues:

### 1. Domain Mismatch in Saved Passwords

**Problem**: Your password was saved for a different domain than what the app declares.

**Check**:
- Open Settings → Passwords
- Search for "plan with hands" or your email
- Look at what domain/website the password is saved under
- If it says anything OTHER than "plan-with-hands.web.app", that's the issue

**Fix**:
```
1. Delete any passwords saved under wrong domains
2. Log in again using the app
3. When iOS prompts to save, verify it's saving to "plan-with-hands.web.app"
```

### 2. Multiple Apps/Domains for Same Credentials

**Problem**: iOS found passwords for your email but associated with different domains.

**Check**:
- Settings → Passwords → Search for your email
- See how many entries exist
- Check which domains they're associated with

**Fix**:
```
1. Keep only the password for "plan-with-hands.web.app"
2. Delete duplicates or passwords for other domains
3. Test autofill again
```

### 3. Bundle ID Verification Issue

**Problem**: The app's Bundle ID doesn't match what's in `apple-app-site-association`.

**Current Configuration**:
- Entitlements: `webcredentials:plan-with-hands.web.app`
- AASA file has: `M7X5RW4GVL.com.planwithhands.hands`
- Expected Bundle ID: `com.planwithhands.hands`
- Expected Team ID: `M7X5RW4GVL`

**Verify**:
```bash
# Check actual Bundle ID in build
cat ios/Runner.xcodeproj/project.pbxproj | grep PRODUCT_BUNDLE_IDENTIFIER
```

**Fix if mismatched**:
```
1. Update Bundle ID in Xcode or project.pbxproj
2. Rebuild app
3. Reinstall on device
```

### 4. Apple App Site Association Not Loading

**Problem**: iOS can't fetch or verify the AASA file.

**Test**:
```bash
# Verify file is accessible
curl -v https://plan-with-hands.web.app/.well-known/apple-app-site-association

# Should return JSON with your app's Bundle ID
# Should have Content-Type: application/json (not required but recommended)
```

**Check**:
- File is accessible via HTTPS (not HTTP)
- Returns valid JSON
- Contains correct Bundle ID
- No redirects (301/302) from the URL
- No authentication required

**Fix**:
```
1. Ensure firebase.json includes .well-known files:
   "ignore": [
     "firebase.json",
     "**/.*",
     "**/node_modules/**"
   ]
   
2. Add explicit rewrite rule if needed:
   "rewrites": [
     {
       "source": "/.well-known/**",
       "destination": "/.well-known/**"
     }
   ]

3. Redeploy: firebase deploy --only hosting
```

### 5. iOS Cache Issue

**Problem**: iOS cached an old version of the AASA file.

**Symptoms**:
- Changed AASA file but behavior didn't change
- Worked before but stopped after app update
- Works on some devices but not others

**Fix**:
```
1. Delete app completely from device
2. Restart device (forces iOS to clear associated domains cache)
3. Reinstall app
4. Test autofill

OR

1. Go to Settings → General → iPhone Storage
2. Find "Plan with Hands" app
3. Tap "Delete App"
4. Wait 30 seconds
5. Reinstall from TestFlight or App Store
```

### 6. Testing on Simulator

**Problem**: iOS Simulator has limited password autofill support.

**Fix**:
```
❌ Don't test on simulator
✅ Always test on physical iOS device
```

### 7. Password Saved Before Associated Domains Setup

**Problem**: Password was saved before the app had associated domains configured.

**Symptoms**:
- Old password exists but not associated with app
- Must search manually to find it
- iOS doesn't offer it automatically

**Fix**:
```
1. Settings → Passwords
2. Find and DELETE old password entry
3. Log in to app with credentials
4. When iOS prompts "Save Password for plan-with-hands.web.app?", tap Save
5. Next time, it should autofill automatically
```

## Testing Steps for iOS

### Test 1: Fresh Install Password Save
```
1. Delete app completely
2. Restart device
3. Reinstall app
4. Open app to login screen
5. Enter email and password manually
6. Tap "Sign In"
7. ✅ iOS should prompt: "Save Password for plan-with-hands.web.app?"
8. Tap "Save Password"
```

### Test 2: Password Autofill Recognition
```
1. Force quit app (swipe up from app switcher)
2. Reopen app
3. Tap on email field
4. ✅ Should see "Passwords" button above keyboard
5. Tap "Passwords" (or tap key icon on keyboard)
6. ✅ Should see saved password for "plan-with-hands.web.app" at TOP of list
7. Tap the password
8. ✅ Both email and password should fill automatically
```

### Test 3: Automatic Suggestion
```
1. Force quit app
2. Reopen app  
3. Tap on email field
4. ✅ Should see saved password as QuickType suggestion above keyboard
5. Tap the suggestion
6. ✅ Both fields fill automatically
```

## Common iOS Behaviors

### ✅ Expected Behavior
- Password appears as QuickType suggestion above keyboard
- Tapping password fills BOTH email and password fields
- Password appears at top of password list (not requiring search)
- Shows "plan-with-hands.web.app" as the associated website

### ⚠️ Requires Manual Search When:
- Password saved under different domain
- Multiple accounts exist for same domain
- Associated domains verification failed
- Password saved before associated domains configured
- iOS cache has stale data

### ❌ Never Works When:
- Testing on simulator
- Password saved for completely different app/website
- Associated domains entitlement missing
- AASA file not accessible or invalid
- Bundle ID doesn't match AASA file

## Quick Fix Checklist

Try these in order:

- [ ] **Delete old saved passwords** in Settings → Passwords
- [ ] **Restart iOS device** to clear cache
- [ ] **Delete and reinstall app** completely
- [ ] **Log in fresh** and save new password when prompted
- [ ] **Verify password saved** under "plan-with-hands.web.app" in Settings
- [ ] **Test autofill** by closing and reopening app
- [ ] **Check AASA file** is accessible via curl
- [ ] **Verify Bundle ID** matches entitlements and AASA

## Still Not Working?

### Enable iOS Console Logging

1. Connect iPhone to Mac
2. Open Console.app
3. Select your iPhone
4. Filter for "swcd" (Shared Web Credentials Daemon)
5. Look for errors related to "com.planwithhands.hands"

Common error messages:
- `"Association file not found"` → AASA file not accessible
- `"Bundle ID mismatch"` → Bundle ID doesn't match AASA
- `"Invalid JSON"` → AASA file has syntax error

### Check Associated Domains in Xcode

1. Open `ios/Runner.xcodeproj` in Xcode
2. Select "Runner" target
3. Go to "Signing & Capabilities" tab
4. Verify "Associated Domains" capability is present
5. Should show: `webcredentials:plan-with-hands.web.app`

### Verify Entitlements in Build

```bash
# Extract entitlements from installed app (requires libimobiledevice)
ideviceinfo -u <device-udid> | grep Entitlements

# Or check in build
codesign -d --entitlements - ios/build/Runner.app
```

Should include:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>webcredentials:plan-with-hands.web.app</string>
</array>
```

## Most Likely Fix for Your Situation

Based on "can access saved passwords but must search for it", the most likely cause is:

🎯 **Password was saved under a different domain before associated domains were configured**

**Solution**:
1. Open Settings → Passwords → Search for your email
2. **Delete ALL saved passwords** for Plan with Hands (they're saved under wrong domain)
3. **Delete the app** completely from your device
4. **Restart your iPhone** (important!)
5. **Reinstall** the app (latest build with associated domains)
6. **Log in** with credentials
7. When prompted "Save Password for plan-with-hands.web.app?", tap **Save**
8. **Close app** and reopen
9. Tap email field - password should now autofill automatically ✅

This forces iOS to:
- Clear old domain associations
- Verify new associated domains
- Save password with correct domain
- Recognize app for future autofills

---

**Expected Result After Fix**: When you tap the email field, iOS should show your saved password as a QuickType suggestion above the keyboard, without needing to search.

**Last Updated**: October 15, 2025
