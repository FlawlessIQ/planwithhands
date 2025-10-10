# Daily Summary Activation Implementation

## Overview
This document explains how daily summary notifications (both email and in-app) are automatically enabled when a new organization completes their setup.

## User Flow

### Onboarding Popup
When a manager first logs in to a newly created organization, they see the **CondensedSetupWidget** which displays:
- Setup progress (percentage complete)
- Four setup requirements:
  1. ✅ **Locations** - Create at least one location
  2. ✅ **Shifts** - Define at least one work shift
  3. ✅ **Checklists** - Create at least one checklist template
  4. ✅ **Team Members** - Invite at least one staff member

### The "Ready to Track Performance" Button
Once all four requirements are met, the button becomes active. When clicked:
1. Enables `metricsEnabled: true` on the organization document
2. **NEW:** Automatically enables daily summary notifications with default settings
3. Sets timestamp for when metrics were enabled
4. Logs the activation event

## Implementation Details

### File: `lib/services/organization_setup_service.dart`

#### Method: `enableMetricsTracking()`

**What it does:**
- Verifies all setup requirements are met
- Updates the organization document with metrics and daily summary settings
- Logs the activation for audit purposes

**New Fields Added to Organization Document:**
```dart
{
  'metricsEnabled': true,
  'metricsEnabledAt': Timestamp,
  'dailySummarySettings': {
    'enabled': true,
    'enabledAt': Timestamp,
    'hour': 18,        // 6 PM (default)
    'minute': 0,
    'timezone': 'America/New_York'  // Default timezone
  }
}
```

### File: `lib/widgets/condensed_setup_widget.dart`

The button that triggers this:
```dart
ElevatedButton(
  onPressed: () async {
    await _setupService.enableMetricsTracking(widget.organizationId);
    widget.onMetricsEnabled();
  },
  child: Text('Ready to Track Performance'),
)
```

## Daily Summary System

### Two Types of Summaries

1. **Email Summaries** (Server-side)
   - Sent via Firebase Cloud Functions
   - File: `functions/src/scheduledDailySummary.ts`
   - Scheduled based on `dailySummarySettings.hour` and `dailySummarySettings.minute`
   - Checks if `dailySummarySettings.enabled === true` before sending

2. **In-App Notifications** (Client-side)
   - Sent via Flutter app
   - File: `lib/services/daily_summary_service.dart`
   - Also checks `dailySummarySettings.enabled` before generating

### Default Settings
- **Enabled:** `true` (automatically when setup complete)
- **Time:** 6:00 PM (18:00)
- **Timezone:** America/New_York
- **Recipients:** All manager and admin users (userRole >= 1)

### User Customization
Users can later customize:
- Enable/disable daily summaries
- Change delivery time
- Change timezone
- Per-user email preferences

These settings should be configurable in the Settings/Preferences screen (to be implemented).

## Cloud Function Integration

### File: `functions/src/scheduledDailySummary.ts`

The scheduled function checks:
```typescript
const dailySummarySettings = orgData.dailySummarySettings;
if (!dailySummarySettings || !dailySummarySettings.enabled) {
  console.log(`Daily summary disabled for org ${orgId}`);
  return;
}
```

When enabled is `true`, the function:
1. Collects yesterday's task data
2. Generates summary content
3. Sends emails to all managers/admins in the organization

## Data Flow

```
User clicks "Ready to Track Performance"
    ↓
OrganizationSetupService.enableMetricsTracking()
    ↓
Updates Firestore: organizations/{orgId}
    ├─ metricsEnabled: true
    └─ dailySummarySettings: { enabled: true, ... }
    ↓
Cloud Function (scheduledDailySummary) runs at configured time
    ├─ Checks dailySummarySettings.enabled
    ├─ Collects task data from yesterday
    ├─ Generates email content
    └─ Sends to all managers/admins
    ↓
Users receive daily summary email at 6 PM (default)
```

## Summary Content

The daily summary includes:
- **Overall Completion Rate** - Percentage of tasks completed
- **Missed Tasks** - Count of incomplete tasks
- **Tasks with Notes** - Count and details of tasks with notes
- **Photo-Required Tasks Bypassed** - Tasks that needed photos but didn't get them
- **Carry-Forward Progress** - Status of yesterday's missed tasks completed today
- **Location Breakdown** - Summary by location
- **Shift Performance** - Completion rate by shift
- **Action Items** - Recommended follow-up actions

## Testing

### Verify Daily Summaries are Enabled

1. **Check Organization Document:**
```javascript
// In Firebase Console or Node.js script
const orgDoc = await firestore.collection('organizations').doc(orgId).get();
const data = orgDoc.data();
console.log('Daily Summary Enabled:', data.dailySummarySettings?.enabled);
console.log('Delivery Time:', `${data.dailySummarySettings?.hour}:${data.dailySummarySettings?.minute}`);
```

2. **Test Manual Trigger (Development):**
```bash
cd functions
npm run test:daily-summary -- --org ORG_ID
```

3. **Check Cloud Function Logs:**
```bash
firebase functions:log --only scheduledDailySummary
```

### Expected Behavior After Setup

✅ **Immediately After Clicking Button:**
- Organization document updated with `dailySummarySettings.enabled: true`
- Manager dashboard becomes visible (metrics enabled)

✅ **At 6 PM That Day (or next day):**
- Cloud function triggers for the organization
- Collects yesterday's data
- Sends email summary to all managers/admins

✅ **Daily Thereafter:**
- Summary email sent every day at configured time
- In-app notification appears for managers/admins

## User Experience

### Before Setup Complete
```
┌────────────────────────────────────┐
│   🚀 Complete Your Setup           │
├────────────────────────────────────┤
│ Setup Progress: 75%                │
│ ████████████████░░░░               │
│                                    │
│ Setup Requirements:                │
│ ✅ Locations (1)                   │
│ ✅ Shifts (2)                      │
│ ✅ Checklists (3)                  │
│ ⭕ Team Members (1/2 required)     │
│                                    │
│ [Ready to Track Performance]       │
│     (button disabled)              │
└────────────────────────────────────┘
```

### After Setup Complete
```
┌────────────────────────────────────┐
│   🚀 Complete Your Setup           │
├────────────────────────────────────┤
│ Setup Progress: 100%               │
│ ████████████████████████           │
│                                    │
│ Setup Requirements:                │
│ ✅ Locations (1)                   │
│ ✅ Shifts (2)                      │
│ ✅ Checklists (3)                  │
│ ✅ Team Members (2)                │
│                                    │
│ [Ready to Track Performance]       │
│     (button enabled ✨)            │
└────────────────────────────────────┘
```

### After Clicking Button
```
┌────────────────────────────────────┐
│   📊 MANAGER DASHBOARD              │
├────────────────────────────────────┤
│ Missed Yesterday          Today    │
│ 5 tasks                   8 Live   │
│                                    │
│ Historic Insights    Poor Shifts   │
│                                    │
│ [Task History]                     │
└────────────────────────────────────┘

✅ Daily summaries enabled at 6 PM
📧 You'll receive email updates daily
```

## Future Enhancements

### Settings Screen (To Be Implemented)
Allow users to customize:
- ⏰ Change delivery time
- 🌍 Change timezone
- 📧 Disable/enable email notifications
- 📱 Disable/enable in-app notifications
- 👥 Per-user preferences
- 📍 Per-location summaries

### Advanced Features
- Summary frequency (daily, weekly, monthly)
- Summary scope (location-specific, organization-wide)
- Custom summary templates
- Export to PDF
- Scheduled reports
- Slack/Teams integration

## Troubleshooting

### Daily Summaries Not Being Sent

**1. Check if enabled:**
```javascript
const org = await firestore.collection('organizations').doc(orgId).get();
console.log(org.data().dailySummarySettings);
// Should show: { enabled: true, hour: 18, minute: 0, ... }
```

**2. Check Cloud Function deployment:**
```bash
firebase functions:list
# Should show: scheduledDailySummary (deployed)
```

**3. Check Function logs:**
```bash
firebase functions:log --only scheduledDailySummary --limit 20
# Look for "Daily summary disabled for org" or error messages
```

**4. Verify user email preferences:**
```javascript
const users = await firestore.collection('users')
  .where('organizationId', '==', orgId)
  .where('userRole', '>=', 1)
  .get();
  
users.forEach(doc => {
  const data = doc.data();
  console.log(`${data.email}: dailySummaryEnabled = ${data.notificationPreferences?.dailySummaryEnabled !== false}`);
});
```

### Button Doesn't Enable Summaries

**Check the code in organization_setup_service.dart:**
- Ensure `dailySummarySettings` is in the update call
- Verify no errors in the logs
- Check Firestore security rules allow the update

## Security Considerations

### Firestore Security Rules
Ensure the security rules allow updating `dailySummarySettings`:
```javascript
// In firestore.rules
match /organizations/{orgId} {
  allow update: if 
    request.auth != null &&
    isAdminOrManager(request.auth.uid, orgId) &&
    // Allow updating dailySummarySettings
    request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['metricsEnabled', 'metricsEnabledAt', 'dailySummarySettings', 'updatedAt']);
}
```

### Data Privacy
- Email summaries only sent to managers/admins (userRole >= 1)
- Individual user data not exposed in organization-wide summaries
- User can opt-out of email notifications in their preferences
- Sensitive task notes are not included in summary emails

## Maintenance

### Regular Checks
- Monitor Cloud Function execution count (should match # of orgs × days)
- Check for failed function executions
- Verify email delivery rates
- Review user feedback on summary content

### Performance
- Daily summary generation is cached for 1 hour
- Email sending is batched for efficiency
- Large organizations (>100 locations) may need optimization

## Related Files

### Backend (Cloud Functions)
- `functions/src/scheduledDailySummary.ts` - Main email function
- `functions/src/scheduledDailySummary.js` - Compiled JS

### Frontend (Flutter)
- `lib/services/organization_setup_service.dart` - Setup service (THIS FILE MODIFIED)
- `lib/services/daily_summary_service.dart` - In-app notification service
- `lib/widgets/condensed_setup_widget.dart` - Onboarding popup UI

### Scripts (Testing/Debugging)
- `check_daily_summary_settings.js` - Check current settings
- `test_daily_summary_eligibility.js` - Test org eligibility
- `add_org_notification_preferences.js` - Manually add preferences
- `scripts/set_org_daily_summary_time.js` - Change delivery time

## Summary

By adding `dailySummarySettings.enabled: true` to the organization document when the "Ready to Track Performance" button is clicked, we ensure that:

✅ Daily summaries start automatically after setup
✅ No additional configuration required
✅ Managers get immediate value from the system
✅ Users can customize later if needed
✅ Consistent experience across all organizations

This creates a smooth onboarding experience where metrics tracking and daily summaries work together from day one.
