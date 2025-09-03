# Push Notification Testing Guide

## Step 1: Verify Token Registration
1. Install TestFlight build on device
2. Sign in to the app
3. Go to Firebase Console → Firestore Database → `deviceTokens` collection
4. Look for a document with your user ID
5. Verify: `isActive: true`, recent `updatedAt`, and valid `fcmToken`

## Step 2: Test Permissions
1. In the app, go to Settings → Notifications
2. Should show "Granted" status
3. If "Denied", try tapping "Enable Notifications" button
4. Check iOS Settings → Hands → Notifications should be enabled

## Step 3: Manual FCM Test
1. Copy an FCM token from Firestore `deviceTokens` collection
2. Go to Firebase Console → Cloud Messaging → "Send your first message"
3. Choose "Single device" and paste the token
4. Send test notification - should appear on device

## Step 4: Test Message Notifications
1. Create a message thread with another user
2. Send a message from one account
3. Check if notification appears on the other device
4. Check Firebase Functions logs: `firebase functions:log --only functions:onMessageCreated`

## Step 5: Debug Common Issues

### No FCM Token in Firestore
- Permission denied: Check notification permissions in iOS Settings
- Network issue: Check internet connection
- Code issue: Look for errors in Flutter debug console

### Token Exists But No Notifications
- APNs not configured: Check Firebase Console Cloud Messaging setup
- Invalid token: Try deleting and re-registering token
- App in foreground: Test with app backgrounded

### Functions Not Triggering
- Security rules: Check Firestore rules allow message creation
- Functions errors: Check `firebase functions:log`
- Missing data: Verify messageThread has `recipientUserIds` array

## Expected Results
✅ Token appears in Firestore within 30 seconds of login
✅ Manual FCM test delivers notification to device  
✅ Message between users triggers automatic notification
✅ Functions log shows "Push notifications sent: X successful, Y failed"
