# FCM Token Storage Fix Summary

## Problem
FCM tokens were being stored in a top-level `deviceTokens` collection instead of user-specific paths, likely causing Firebase Security Rules violations and making token management difficult.

## Root Cause
The `PushNotificationService` and `TokenRegistrationService` were writing tokens to:
```
collection('deviceTokens').doc('${userId}_${token}')
```

This creates a top-level collection accessible globally, which can cause security rule issues.

## Solution Applied

### 1. Updated Client-Side Token Storage

**Files Changed:**
- `lib/services/push_notification_service.dart`
- `lib/features/messaging/services/token_registration_service.dart`

**Changes:**
- Tokens now stored in user-specific subcollections: `users/{uid}/deviceTokens/{tokenHash}`
- Added `lastFcmToken` field to user document for quick access
- Added token cleanup logic to remove old/inactive tokens
- Better error handling and logging

### 2. Updated Cloud Functions

**File Changed:**
- `functions/src/messagingNotifications.ts`

**Changes:**
- Updated all token queries to check user-specific subcollections first
- Added fallback to legacy top-level collection for backward compatibility
- Updated token cleanup function to handle both new and legacy storage
- Built functions with `npm run build`

### 3. Updated Debug Tools

**Files Changed:**
- `lib/debug_push_test.dart`

**Changes:**
- Updated diagnostics to check new user-specific token paths
- Added checks for legacy collection as fallback
- Improved error reporting

## New Token Storage Structure

### New Format (Post-Fix)
```
users/{uid}/deviceTokens/{tokenHash}/
  - fcmToken: "actual_token_string"
  - isActive: true
  - platform: "ios|android|web"
  - updatedAt: timestamp
  - expiresAt: timestamp

users/{uid}/
  - lastFcmToken: "actual_token_string"
  - lastFcmTokenUpdatedAt: timestamp
```

### Legacy Format (Pre-Fix)
```
deviceTokens/{userId}_{token}/
  - userId: "user_id"
  - fcmToken: "actual_token_string"
  - isActive: true
  - platform: "ios|android|web"
  - updatedAt: timestamp
  - expiresAt: timestamp
```

## Testing

### Manual Test Steps
1. Sign in with a test user
2. Check Firestore console:
   - Verify no new entries in top-level `deviceTokens` collection
   - Verify token appears in `users/{uid}/deviceTokens/`
   - Verify `lastFcmToken` updated on user document

### Automated Test
- Created `test_token_fix.dart` widget for testing
- Use `PushNotificationDebugger.runDiagnostics(userId)` to verify

### Console Verification
```bash
# Check for token writes in logs
flutter run -d chrome
# Watch for log messages:
# ✅ Token persisted successfully for user {uid}
# ✅ Cleaned up X old tokens
```

## Deployment

### Client App
- Changes are ready for next app deployment
- Backward compatible with existing tokens

### Cloud Functions
- Functions built and ready for deployment
- Run: `firebase deploy --only functions`

## Migration Notes

### Existing Users
- Legacy tokens in top-level collection will still work
- New tokens will be stored in user-specific paths
- Old tokens will be gradually migrated as users sign in

### Security Rules
- May need to update Firestore rules to allow access to `users/{uid}/deviceTokens`
- Example rule:
```javascript
match /users/{userId}/deviceTokens/{tokenId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Benefits

1. **Security**: Tokens stored in user-specific paths with proper access control
2. **Performance**: Easier to query user's tokens without global collection scans
3. **Maintenance**: Automatic cleanup of old tokens per user
4. **Debugging**: Clear association between users and their tokens

## Next Steps

1. Deploy cloud functions: `firebase deploy --only functions`
2. Test with a fresh user sign-up
3. Monitor logs for successful token storage
4. Update Firestore security rules if needed
5. Consider cleanup script for legacy tokens after migration period
