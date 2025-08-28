# Messaging Push Notifications Integration

## Overview

This document describes the complete integration between the messaging system and push notifications in the Hands app. The integration ensures that users receive native push notifications when new messages are sent in threads they're part of.

## Architecture

### Components

1. **Flutter MessagingService** (`lib/features/messaging/services/messaging_service.dart`)
   - Handles creating message threads and sending messages
   - Optionally triggers push notifications via Cloud Function
   - Manages message and notification storage

2. **Firebase Cloud Functions** (`functions/src/messagingNotifications.ts`)
   - **`onMessageCreated`**: Firestore trigger that automatically sends push notifications when messages are created
   - **`sendMessageNotification`**: Callable function for explicit notification sending
   - **`cleanupInvalidTokens`**: Helper function to manage FCM token lifecycle

3. **PushNotificationService** (`lib/services/push_notification_service.dart`)
   - Handles FCM token registration and management
   - Processes incoming push notifications
   - Manages notification permissions and settings

4. **TokenRegistrationService** (`lib/services/token_registration_service.dart`)
   - Registers FCM tokens to Firestore with device information
   - Maintains active token status for push notification targeting

## How It Works

### Message Flow with Push Notifications

1. **User sends message**: `MessagingService.sendMessage()` is called
2. **Message stored**: Message document created in `messageThreads/{threadId}/messages`
3. **Trigger activated**: `onMessageCreated` Cloud Function automatically triggers
4. **Recipients identified**: Function reads thread data to find recipient user IDs
5. **Tokens retrieved**: Active FCM tokens fetched for each recipient
6. **Notifications created**: Notification documents created in Firestore
7. **Push sent**: FCM multicast message sent to all recipient tokens
8. **Token cleanup**: Invalid tokens automatically marked as inactive

### Firestore Trigger Method (Recommended)

The `onMessageCreated` function automatically triggers whenever a message document is created:

```typescript
export const onMessageCreated = functions.firestore
    .document("messageThreads/{threadId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
        // Automatically processes new messages and sends notifications
    });
```

### Callable Function Method (Alternative)

The `sendMessageNotification` function can be explicitly called from Flutter:

```dart
final callable = _functions.httpsCallable('sendMessageNotification');
await callable.call({
  'threadId': threadId,
  'messageText': text,
  'recipientUserIds': recipientUserIds,
});
```

## Implementation Details

### Cloud Function Features

- **Automatic sender exclusion**: Senders don't receive notifications for their own messages
- **Token validation**: Invalid FCM tokens are automatically cleaned up
- **TTL management**: Notification documents expire after 30 days
- **Error handling**: Comprehensive error logging and graceful failure handling
- **Batch operations**: Efficient Firestore batch writes for multiple notifications

### Data Structures

#### FCM Message Format
```javascript
{
  notification: {
    title: "John Smith",
    body: "Hey, can you check on the evening shift?"
  },
  data: {
    type: "message",
    threadId: "thread123",
    messageId: "msg456", 
    senderId: "user789",
    senderName: "John Smith",
    orgId: "org123"
  },
  tokens: ["fcm_token_1", "fcm_token_2", ...]
}
```

#### Notification Document
```javascript
{
  userId: "recipient_user_id",
  orgId: "organization_id", 
  threadId: "message_thread_id",
  type: "message",
  title: "John Smith",
  message: "Hey, can you check on...",
  read: false,
  createdAt: timestamp,
  senderId: "sender_user_id",
  senderName: "John Smith",
  expiresAt: timestamp_30_days_later
}
```

## Configuration

### Firebase Console Setup

1. **Enable Cloud Functions API**
2. **Enable Firebase Cloud Messaging**
3. **Configure FCM server key** (for older versions)
4. **Set up service account permissions**

### Flutter Configuration

The messaging service includes optional notification triggering:

```dart
Future<void> sendMessage(String threadId, String text, {bool sendNotifications = true}) async {
  // Store message in Firestore
  // Optionally trigger push notifications
}
```

### Environment Variables

No additional environment variables needed - the system uses Firebase project configuration.

## Testing

### Manual Testing Steps

1. **Create a message thread** with multiple users
2. **Send a message** from one user account
3. **Verify notification creation** in Firestore console
4. **Check FCM delivery** in Firebase console logs
5. **Confirm mobile notification** appears on recipient devices

### Debugging

#### Cloud Function Logs
```bash
firebase functions:log --only functions:onMessageCreated
```

#### Common Issues

1. **No notifications received**
   - Check FCM token registration in `deviceTokens` collection
   - Verify `isActive: true` for tokens
   - Confirm thread has `recipientUserIds` array

2. **Function not triggering**
   - Verify function deployment: `firebase functions:list`
   - Check Firestore security rules allow message creation
   - Review function logs for errors

3. **Invalid tokens**
   - Token cleanup happens automatically
   - Monitor `cleanupInvalidTokens` function logs

## Security Considerations

### Firestore Rules

Ensure message creation triggers the function:

```javascript
// messages subcollection rules
allow create: if request.auth != null && 
  request.auth.uid in get(/databases/$(database)/documents/messageThreads/$(threadId)).data.recipientUserIds;
```

### Function Permissions

- Functions run with admin privileges
- Token access limited to active tokens only  
- User data access restricted to thread participants

## Performance Optimization

### Batch Operations
- Notification creation uses Firestore batch writes
- FCM sending uses multicast for efficiency
- Invalid token cleanup batched

### Token Management
- Inactive tokens automatically excluded
- Periodic cleanup prevents token accumulation
- Device-specific token registration

## Monitoring

### Key Metrics
- Message notification success rate
- FCM delivery success rate  
- Token cleanup frequency
- Function execution time

### Alerts
Monitor for:
- High function error rates
- FCM quota exhaustion
- Unusual token failure rates

## Deployment

### Deploy Functions Only
```bash
firebase deploy --only functions:onMessageCreated,functions:sendMessageNotification
```

### Full Deployment
```bash
firebase deploy
```

### Rollback
```bash
firebase functions:delete onMessageCreated
firebase functions:delete sendMessageNotification
```

## Future Enhancements

### Possible Improvements
1. **Rich notifications** with user avatars
2. **Notification grouping** by thread
3. **Custom notification sounds**
4. **Notification scheduling** for different time zones
5. **A/B testing** for notification content

### Scaling Considerations
- **Regional functions** for global latency
- **Notification queuing** for high-volume scenarios  
- **Advanced token management** with expiration tracking

## Troubleshooting Guide

### No Push Notifications

1. Check function deployment: `firebase functions:list`
2. Verify FCM token registration in Firestore
3. Confirm `recipientUserIds` in thread document
4. Review Cloud Function logs for errors

### Partial Delivery

1. Check for invalid FCM tokens
2. Verify network connectivity for recipients  
3. Review notification permission status
4. Monitor FCM quota limits

### High Latency

1. Monitor function execution times
2. Check Firestore read/write patterns
3. Consider regional function deployment
4. Optimize batch operations

---

## Status: ✅ Fully Implemented

- ✅ Cloud Functions deployed and active
- ✅ Firestore trigger configured  
- ✅ Flutter integration complete
- ✅ Token management working
- ✅ Push notifications sending
- ✅ Error handling implemented
- ✅ Documentation complete

**Next Steps**: Test in production environment and monitor notification delivery rates.
