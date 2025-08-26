# DeviceTokens TTL (Time To Live) Configuration

## Overview

The `deviceTokens` collection now includes automatic TTL (Time To Live) functionality to automatically clean up expired device tokens after 30 days.

## Implementation Details

### Code Changes
- **File**: `lib/features/messaging/services/token_registration_service.dart`
- **Field Added**: `expiresAt` (Timestamp)
- **TTL Duration**: 30 days from document creation/update
- **Behavior**: Idempotent - each call to `registerCurrentDevice()` refreshes both `updatedAt` and `expiresAt`

### Document Structure
```dart
{
  'userId': String,
  'fcmToken': String,
  'platform': String,        // 'ios', 'android', 'web', 'other'
  'updatedAt': FieldValue.serverTimestamp(),
  'expiresAt': Timestamp,    // Current time + 30 days
}
```

## Firebase Console Configuration

To enable automatic TTL cleanup in Firebase Console:

### Step 1: Navigate to Firestore TTL Settings
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database**
4. Click on **TTL** in the left sidebar

### Step 2: Create TTL Policy
1. Click **Create TTL policy**
2. Configure the following:
   - **Collection group**: `deviceTokens`
   - **TTL field**: `expiresAt`
   - **Collection scope**: Single collection
3. Click **Create policy**

### Step 3: Monitor TTL Policy
- TTL policies may take up to 72 hours to start working
- Check the TTL dashboard for policy status and deletion metrics
- Documents will be deleted automatically when their `expiresAt` timestamp is reached

## Validation

### Testing TTL Implementation
Run the unit tests to verify TTL structure:
```bash
flutter test test/services/token_registration_service_test.dart
```

### Manual Verification
1. Create a new device token by logging in
2. Check Firestore Console for the document
3. Verify `expiresAt` field exists and is ~30 days in the future
4. Register the same device again - `expiresAt` should be refreshed

### Expected Behavior
- ✅ Each device token registration includes `expiresAt`
- ✅ Multiple registrations from same device refresh the TTL
- ✅ Documents expire exactly 30 days after their `expiresAt` timestamp
- ✅ No manual cleanup required

## Troubleshooting

### Common Issues
1. **TTL policy not working**: Wait up to 72 hours after creation
2. **Documents not expiring**: Verify the TTL field name matches exactly (`expiresAt`)
3. **Performance impact**: TTL cleanup runs automatically in background

### Monitoring
- Check Firebase Console → Firestore → TTL for deletion metrics
- Monitor Cloud Functions logs for any TTL-related errors
- Verify expired tokens are not being used for push notifications

## Related Files
- `lib/features/messaging/services/token_registration_service.dart` - Main implementation
- `lib/state/auth_controller.dart` - Token registration call site
- `test/services/token_registration_service_test.dart` - TTL validation tests
- `firestore.rules` - Security rules for deviceTokens collection
