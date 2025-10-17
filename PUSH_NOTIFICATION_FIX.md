# Push Notification Fix - iOS Devices

## Issue
Push notifications were not being delivered to iOS devices for ANY notifications sent from the app:
- ❌ Daily summary notifications
- ❌ Manual notifications sent via Admin → Send Notification
- ❌ Group notifications
- ❌ Location notifications

The messages were being created and stored in the app (in-app notifications were working), but FCM push notifications were not appearing on iOS devices.

## Root Cause
There were TWO separate issues causing iOS push notification failures:

### 1. Daily Summary Notifications - Missing FCM Send Logic
The `sendNotificationToAdmins()` function in `scheduledDailySummary.ts` was creating notifications in two places:
- **notificationOutbox** - Would trigger fan-out, but used wrong targetType
- **userNotifications** - Direct writes that bypassed FCM sending

The function created individual userNotifications directly for admin users, which completely bypassed the FCM notification sending logic.

### 2. General Notifications - Missing APNS Payload
The `onNotificationOutboxCreated` trigger in `messagingNotifications.ts` was sending FCM messages but was **missing the APNS payload configuration**. 

iOS requires specific APNS configuration in FCM messages:
```typescript
apns: {
  payload: {
    aps: {
      sound: "default",
      badge: 1,
    },
  },
}
```

Without this payload, FCM successfully sends the message but iOS silently drops it and never shows a notification to the user.

## Solution

### Fix #1: Daily Summary Function
Added FCM push notification sending directly to the `sendNotificationToAdmins()` function in `scheduledDailySummary.ts`:

1. **Token Retrieval**: Fetch FCM tokens for all admin users
2. **Token Deduplication**: Combine and deduplicate tokens
3. **FCM Message with APNS**: Build FCM message with iOS-specific APNS payload
4. **Batch Sending**: Send in chunks of 500 tokens
5. **Error Handling**: Log sample errors for diagnostics

### Fix #2: General Notifications Function
Updated the `onNotificationOutboxCreated()` trigger in `messagingNotifications.ts` to include APNS payload:

```typescript
const baseMessage = {
  notification: {
    title: notif.title || "Hands Notification",
    body: notif.message || "",
  },
  data: {
    type: "general_notification",
    orgId: orgId,
    outboxId: notifId,
  },
  apns: {
    payload: {
      aps: {
        sound: "default",
        badge: 1,
      },
    },
  },
};
```

This ensures ALL notifications sent via the outbox system (from `lib/pages/admin/send_notification_sheet.dart`) now properly deliver to iOS devices.

## Files Changed

### 1. `functions/src/scheduledDailySummary.ts`
- **Function**: `sendNotificationToAdmins()`
- **Change**: Added complete FCM push notification sending with APNS payload
- **Lines**: ~1138-1290 (added ~100 lines)
- **Impact**: Daily summary notifications now send to iOS

### 2. `functions/src/messagingNotifications.ts`  
- **Function**: `onNotificationOutboxCreated` (trigger)
- **Change**: Added APNS payload to FCM message
- **Lines**: ~200-217
- **Impact**: All manual/group/location notifications now send to iOS

## Testing

### Test Daily Summary Notifications
1. **Manual trigger**:
   ```bash
   node functions/trigger_daily_summary_manual.js
   ```

2. **Check logs**:
   ```bash
   firebase functions:log --only scheduledDailySummary
   ```

3. **Look for**:
   - `🔔 Sending push notifications to X tokens for daily summary`
   - `✅ Push notifications sent: X successful, Y failed`

### Test Manual Notifications
1. **In app**: Go to Admin → Send Notification
2. **Send to**: "All Users" or specific Group/Location
3. **Check iOS device**: Should receive push notification immediately

### Verify on iOS Device
- ✅ Ensure notifications enabled: Settings → Hands App → Notifications
- ✅ App has proper permissions
- ✅ Device receives both notification sound and banner

## Deployment

```bash
cd functions
npm run build
cd ..
firebase deploy --only functions:scheduledDailySummary,functions:onNotificationOutboxCreated
```

**Status**: ✅ Both functions deployed to production on October 16, 2025

## Key Points

### APNS Payload is Critical for iOS
The most important fix was adding the APNS payload. Without it:
- ✅ FCM accepts and "sends" the message
- ✅ No errors are logged
- ❌ iOS silently drops the notification
- ❌ Users never see anything

### Notification Flow
```
Admin sends notification
    ↓
NotificationController.sendNotification()
    ↓
Write to organizations/{orgId}/notificationOutbox/{id}
    ↓
Trigger: onNotificationOutboxCreated
    ↓
1. Fan out to userNotifications (in-app)
2. Fetch FCM tokens
3. Send FCM messages WITH APNS payload
    ↓
iOS device receives and displays notification
```

### Both Fixes Were Needed
- **Daily Summary**: Needed its own FCM sending logic (bypassed outbox)
- **General Notifications**: Needed APNS payload in outbox trigger
- Both now include proper APNS configuration for iOS

## Future Improvements

1. **Consolidate Notification Sending**: Consider using only the outbox system with proper admin targeting instead of direct userNotifications writes

2. **Add Android-specific Configuration**: Could add Android-specific options like notification channels, priority, etc.

3. **Badge Management**: Implement proper badge counting instead of always setting to 1

4. **Rich Notifications**: Add support for images, actions, categories for richer iOS notifications

5. **Test Notification Tool**: Add admin UI to send test notifications to verify delivery
