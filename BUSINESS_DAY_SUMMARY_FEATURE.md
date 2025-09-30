# Business Day Summary Period Feature

## Overview

The Business Day Summary Period feature allows users to choose between two different data collection periods for their daily summary emails:

1. **Calendar Day (6am-6am)** - Traditional daily summary covering tasks from 6 AM to 6 AM
2. **Business Day** - Covers tasks from yesterday evening through today, perfect for businesses with late-night operations

## Use Case

This feature was specifically designed for businesses like bars, restaurants, and 24-hour operations that have shifts extending past midnight. For example:

- **Bar closing at 2 AM**: The bar's closing tasks at 2 AM should be included in "tomorrow's" summary, not today's
- **Restaurant with late cleanup**: Kitchen breakdown and cleaning tasks happening at 1-3 AM should be part of the next day's operational summary
- **24-hour operations**: Need comprehensive coverage across shift changes

## User Interface

### Settings Location
Navigate to: **Settings > Preferences > Daily Summary Email**

### New UI Element
After enabling daily summary and setting the time, users will see:

```
Summary Period                              [Business Day ▼]
Which tasks to include in your daily summary
```

### Options
- **Today (6am-6am)** - Standard calendar day
- **Business Day** - Yesterday close to today close

## Technical Implementation

### Database Structure

The feature adds a new field to the organization's daily summary settings:

```javascript
organizations/{orgId} {
  dailySummarySettings: {
    enabled: true,
    hour: 10,           // 10 AM
    minute: 0,
    summaryPeriod: "business-day"  // NEW FIELD
  }
}
```

### Supported Values
- `"calendar-day"` - Default for backward compatibility
- `"business-day"` - New business day mode

### Cloud Function Changes

The `scheduledDailySummary` function now:

1. Reads the `summaryPeriod` setting from each organization
2. For `calendar-day`: Queries tasks from the target date only
3. For `business-day`: Queries tasks from both yesterday and today
4. Combines and processes the data appropriately
5. Includes period indicator in email content

## Example Scenarios

### Scenario 1: Downtown Bar
- **Business**: Bar that closes at 2:30 AM
- **Summary Time**: 10:00 AM
- **Summary Period**: Business Day
- **Result**: 10 AM summary includes last night's closing tasks and today's prep tasks

### Scenario 2: Coffee Shop
- **Business**: Coffee shop, 6 AM - 8 PM
- **Summary Time**: 8:30 PM  
- **Summary Period**: Calendar Day
- **Result**: Traditional 8:30 PM summary covers today's tasks only

### Scenario 3: 24-Hour Diner
- **Business**: Never closes
- **Summary Time**: 6:00 AM
- **Summary Period**: Business Day
- **Result**: 6 AM summary covers yesterday evening through today morning

## Email Content Changes

### Business Day Mode
```
📊 Daily Summary (Business Day) - Downtown Bar

Overall Progress: 92% (87/95 tasks completed)
Includes: Yesterday evening through today

✅ Great job! Strong performance across all shifts.

❌ Missed Tasks (3):
• Deep clean fryers - Equipment issue
• Lock back door - Keys missing  
• Final trash pickup - Missed by night crew
```

### Calendar Day Mode
```
📊 Daily Summary - Morning Coffee

Overall Progress: 95% (76/80 tasks completed)
Standard daily summary (6am-6am)

🎉 Outstanding work! Nearly perfect completion rate.
```

## Migration and Backward Compatibility

- **Existing Users**: Automatically default to `calendar-day` mode
- **New Users**: Can choose either option during setup
- **No Data Loss**: All existing functionality preserved
- **Gradual Adoption**: Users can switch modes anytime

## Benefits

1. **Flexible Timing**: Choose what works for your business operations
2. **Complete Coverage**: Business Day mode captures late-night operations
3. **Better Insights**: More relevant data for operational decisions
4. **Easy Setup**: Simple toggle in settings UI
5. **Backward Compatible**: No disruption to existing users

## Deployment Status

- ✅ **Flutter UI**: Updated settings page with new toggle
- ✅ **Database Schema**: Added `summaryPeriod` field support
- ✅ **Cloud Function**: Updated `scheduledDailySummary` function
- ✅ **Email Content**: Added period indicator
- ✅ **Backward Compatibility**: Maintained for existing users

## Future Enhancements

Potential improvements for future versions:

1. **Custom Time Ranges**: Allow users to define specific start/end hours for business day
2. **Shift-Based Filtering**: Filter by specific shift types or locations
3. **Multi-Location Support**: Different periods for different locations
4. **Analytics**: Track which period type works better for different business types

## Testing

To test this feature:

1. **Admin User Setup**:
   - Go to Settings > Preferences
   - Enable Daily Summary Email
   - Set a time (e.g., 11:00 AM)
   - Choose "Business Day" period
   - Save settings

2. **Verification**:
   - Check Firestore for updated `dailySummarySettings`
   - Monitor Cloud Function logs for period-aware processing
   - Receive email with "(Business Day)" indicator

3. **Business Day vs Calendar Day**:
   - Compare email content between the two modes
   - Verify yesterday's late tasks appear in Business Day mode
   - Confirm Calendar Day mode only includes target date tasks

## Support

This feature addresses the specific need for businesses with late-night operations to receive relevant daily summaries that include all operational tasks, regardless of when they were completed relative to calendar day boundaries.

Perfect for the use case: "Bar shifts may run until 2am, but I want the daily summary tomorrow morning at 9am including those late-night tasks."