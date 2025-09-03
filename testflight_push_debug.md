# TestFlight Push Notification Verification Steps

## After Configuring APNs in Firebase Console:

### Test 1: Manual FCM Test
1. Install TestFlight build on device
2. Sign in and ensure you see notifications permission granted
3. Go to Firebase Console → Firestore → `deviceTokens` collection
4. Copy an FCM token for your user
5. Go to Firebase Console → Cloud Messaging → "Send your first message"
6. Target: Single device, paste token
7. Send test - should appear on device immediately

### Test 2: In-App Message Test  
1. Create message thread with another user
2. Send message from one account
3. Should see notification on other device
4. Check logs: `firebase functions:log --only functions:onMessageCreated`

### Test 3: Debug Token Registration
Add this to your app temporarily to verify tokens are being stored:

```dart
// In auth_controller.dart after login success, add:
final token = await FirebaseMessaging.instance.getToken();
print('DEBUG FCM Token: ${token?.substring(0, 20)}...');

final docId = '${userId}_$token';
final tokenDoc = await FirebaseFirestore.instance
    .collection('deviceTokens')
    .doc(docId)
    .get();
    
if (tokenDoc.exists) {
  print('✅ Token stored in Firestore: ${tokenDoc.data()}');
} else {
  print('❌ Token NOT stored in Firestore');
}
```

## Expected Results:
✅ Manual FCM test delivers to TestFlight build
✅ Token appears in Firestore `deviceTokens` collection  
✅ Message notifications work between users
✅ Function logs show "Push notifications sent: X successful"

## If Still Not Working:
1. Check Apple Developer Console → Identifiers → App ID → Push Notifications capability is enabled
2. Verify TestFlight build was signed with proper provisioning profile
3. Check iOS Settings → Hands → Notifications is enabled
4. Try deleting and reinstalling TestFlight app to reset notification permissions
