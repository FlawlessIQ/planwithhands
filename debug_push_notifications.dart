#!/usr/bin/env dart
// Debug script to check push notification setup
// Run this in the app to verify tokens are being registered

void main() {
  print('''
=== Push Notifications Debug Checklist ===

1. Check if FCM tokens are being generated and stored:
   - Open Firebase Console → Firestore → deviceTokens collection
   - Look for documents with your user ID
   - Verify isActive: true and recent updatedAt timestamp

2. Test permission status in app:
   - Check Settings → Notifications in your app
   - Should show "Granted" status
   - If not, try requesting permissions again

3. Verify message sending:
   - Send a message in the app
   - Check Firebase Functions logs: firebase functions:log --only functions:onMessageCreated
   - Look for "Push notifications sent: X successful, Y failed"

4. Test with Firebase Console:
   - Go to Firebase Console → Cloud Messaging → Send your first message
   - Target: Single device
   - Use an FCM token from Firestore deviceTokens collection
   - Send test message

5. Check TestFlight build configuration:
   - Ensure built with --release flag
   - Verify provisioning profile includes Push Notifications capability
   - Check if bundle ID matches Firebase project

6. APNs Certificate Check (CRITICAL for TestFlight):
   - Firebase Console → Project Settings → Cloud Messaging
   - Under Apple app configuration, verify Production certificate/key is present
   - Bundle ID must be: com.planwithhands.hands

Common Issues:
- APNs certificates not configured for production
- Notification permissions not granted
- App not requesting permissions properly
- Functions not triggering due to security rules
- Invalid or expired FCM tokens

Next Steps:
1. Check APNs configuration in Firebase Console (most likely issue)
2. Test with a simple FCM test message from console
3. Verify Firestore security rules allow token writes
4. Check if TestFlight build has proper entitlements
''');
}
