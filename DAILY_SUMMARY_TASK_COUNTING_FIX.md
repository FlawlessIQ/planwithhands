# Daily Summary Task Counting Bug Fix

## Issue Description
The daily summary email was showing incorrect task counts - **counting tasks twice** which resulted in inflated numbers (e.g., showing 223 tasks when there were only 46 actual tasks).

## Root Cause
In `functions/lib/scheduledDailySummary.js` (JavaScript Cloud Function), the `collectDailySummaryData` method was processing tasks from **both** storage locations:

1. **Subcollection** (`daily_checklists/{id}/tasks/...`) - New system
2. **Legacy array** (`daily_checklists/{id}.tasks[]`) - Old system

The code was adding tasks from BOTH sources to the count, even though they're the same tasks stored in two places during the migration period.

## Code Location
File: `functions/lib/scheduledDailySummary.js`
Lines: ~242-283 (in the `collectDailySummaryData` function)

## The Fix
Changed the logic to use **if/else** instead of processing both:

### Before (BUGGY):
```javascript
// Process tasks from subcollection
const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();
for (const taskDoc of tasksSnapshot.docs) {
    // ... process and count task
    totalTasks++;
}

// Also process legacy tasks array
const tasks = checklistData.tasks || [];
for (const taskData of tasks) {
    // ... process and count task
    totalTasks++;  // ❌ DUPLICATE COUNT!
}
```

### After (FIXED):
```javascript
// Try subcollection first
const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();
const hasSubcollectionTasks = !tasksSnapshot.empty;

if (hasSubcollectionTasks) {
    // Use subcollection tasks (new system)
    for (const taskDoc of tasksSnapshot.docs) {
        // ... process and count task
        totalTasks++;
    }
} else {
    // Fall back to legacy array only if subcollection is empty
    const tasks = checklistData.tasks || [];
    for (const taskData of tasks) {
        // ... process and count task
        totalTasks++;
    }
}
```

## Impact
- ✅ Daily summary emails now show correct task counts
- ✅ Completion percentages are accurate
- ✅ "Incomplete tasks" count is correct
- ✅ Performance metrics reflect actual work done

## Testing
To verify the fix:
1. Check a daily summary email - task counts should match the actual number of tasks across all shifts
2. Verify in admin dashboard that shift checklist tasks match the summary counts
3. Compare total tasks in summary with the sum of tasks per checklist template

## Related Files
- `functions/lib/scheduledDailySummary.js` - **FIXED** (JavaScript Cloud Function)
- `lib/services/daily_summary_service.dart` - Also fixed (Dart version, though not currently used)
- `lib/features/dashboard/pages/manager_dashboard_page.dart` - Already correct (uses if/else)
- `lib/services/daily_checklist_service.dart` - Various methods handle both formats correctly

## Deployment Type
**Firebase Functions Only** - No iOS/Android app update required!

The daily summary runs server-side in Cloud Functions, so only a functions deployment was needed:
```bash
cd functions
firebase deploy --only functions
```

Deployed successfully on October 7, 2025.

## Migration Context
This bug only occurred during the migration period when tasks existed in BOTH storage locations:
- New installations: Only use subcollections (no issue)
- Fully migrated installations: Only have subcollections (no issue)  
- **During migration**: Tasks in BOTH places (this bug occurred)

The fix ensures we count from only one source, prioritizing the new subcollection system while maintaining backward compatibility.

## Date Fixed
October 7, 2025
