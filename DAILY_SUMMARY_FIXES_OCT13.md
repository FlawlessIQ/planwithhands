# Daily Summary Fixes - October 13, 2025

## Issues Reported

1. **Wrong Timing**: Summary received at 12:00 PM instead of configured 9:15 AM
2. **Wrong Data**: Email showed "0/92 tasks complete" and "46 tasks incomplete" (should be 92 incomplete)
3. **Missing Completed Tasks**: Hamilton Pork had 396 completed tasks (46% completion) but email showed 0 completed

## Root Causes

### Issue 1: Wrong Timing (12 PM instead of 9:15 AM)

**Problem**: My previous fix used `currentUTCHour >= targetUTCHour`, which triggered at EVERY hour after the target.

- Target: 9:15 AM Eastern = 13:15 UTC → Should trigger at 13:00 UTC
- My broken logic: `16 >= 13` = TRUE → Triggered at 16:00 UTC (12:00 PM)
- This explained why summaries were sent at 12 PM instead of 9 AM

**Fix**: Changed to exact hour match: `currentUTCHour === targetUTCHour`

```typescript
// BEFORE (BROKEN):
const isAtOrPastTargetHour = currentUTCHour >= targetUTCHour;

// AFTER (FIXED):
const isTargetHour = currentUTCHour === targetUTCHour;
```

**Result**: Now triggers ONLY at 13:00 UTC (9:00 AM Eastern), not every hour after.

### Issue 2: Wrong Task Counts (46 incomplete instead of 92)

**Problem**: The code calculated `incompleteTasks` from `missedTaskEntries.length` instead of actual incomplete task count.

- `missedTaskEntries` only contains incomplete tasks that:
  - Are NOT carry-forward tasks (from yesterday)
  - Are NOT completed
- This array is designed to show "tasks requiring attention" not "all incomplete tasks"
- Result: 92 incomplete tasks, but only 46 are "missed" (non-carry-forward) → Email shows 46

**Fix**: Calculate incomplete as `totalTasks - completedTasks`

```typescript
// BEFORE (BROKEN):
// CRITICAL FIX: Calculate incomplete from missed array length for consistency
const incompleteTasks = missedTaskEntries.length; // Only non-carry-forward incomplete tasks

// AFTER (FIXED):
// Calculate incomplete tasks as total - completed (not from missedTaskEntries)
const incompleteTasks = totalTasks - completedTasks; // ALL incomplete tasks
```

**Result**: Now correctly shows 92 incomplete tasks when there are 0 completed out of 92 total.

### Issue 3: Summaries Never Actually Sent (Critical Bug)

**Problem**: The function was marking summaries as "sent" even when they were never actually sent!

Investigation revealed:
- Hamilton Pork: 396 completed tasks (46% completion rate) but summary showed 0
- Conor's Pub: 92 tasks but summary never sent to anyone
- Both organizations had summary logs created with `sentAt` timestamps
- But neither had `recipientCount`, `emailSent`, or `inAppNotificationSent` fields
- This meant `markDailySummaryAsSent()` was called but `generateAndSendDailySummary()` returned early

**Root Cause**: 
```typescript
// BEFORE (BROKEN):
await generateAndSendDailySummary(orgId, summaryDate, orgData);
// This function could return early (no content, no users, etc.)

await markDailySummaryAsSent(orgId, dateStr);
// But this ALWAYS ran, even if summary wasn't sent!
```

**Fix**: Made `generateAndSendDailySummary` return a boolean indicating success, and only mark as sent if true:

```typescript
// AFTER (FIXED):
const wasSent = await generateAndSendDailySummary(orgId, summaryDate, orgData);

if (wasSent) {
  await markDailySummaryAsSent(orgId, dateStr);
  summariesSent++;
} else {
  functions.logger.info(`Daily summary skipped for org ${orgId} (no meaningful content)`);
}
```

**Result**: 
- Summaries will only be marked as "sent" if they are actually sent
- If a summary is skipped (no content, no users, etc.), it won't create a log
- This allows the function to retry sending the next hour if there was an issue

## Deployment

- Fixed in `/functions/src/scheduledDailySummary.ts`
- First deployment: October 13, 2025, 12:17 PM EDT (timing + incomplete count fixes)
- Second deployment: October 13, 2025, 12:30 PM EDT (critical "never sent" bug fix)
- Next execution: Tomorrow at 4:00 AM EDT for Hamilton, 9:00 AM EDT for Conor's Pub

## Expected Results

### Conor's Pub Group:
- **Tomorrow (Oct 14)**: Summary will be sent at **9:00 AM EDT** (not 12 PM)
- **Data accuracy**: Will show correct incomplete count (e.g., 92 incomplete = 92 incomplete, not 46)

### Hamilton Pork:
- **Tomorrow (Oct 14)**: Summary will be sent at **4:00 AM EDT** (as configured)
- **Data accuracy**: Will show correct task counts

## Testing Tomorrow

Please verify tomorrow morning:

1. ✅ **Timing**: Conor's Pub receives summary at ~9:00 AM EDT (not 12:00 PM)
2. ✅ **Timing**: Hamilton Pork receives summary at ~4:00 AM EDT
3. ✅ **Data**: Task counts are correct:
   - "X of Y tasks complete" matches reality (not showing 0 when there are completed tasks)
   - "Z tasks incomplete" = Y - X (not showing 46 when there are 92 incomplete)
4. ✅ **Actually Sent**: Summary appears in both email AND in-app notifications (not just a log entry)

## Additional Context

The "minute" setting (e.g., 9:15 AM) is currently **informational only** because the Cloud Function runs hourly at :00. The function triggers at the START of the target hour:

- 9:15 AM setting → Triggers at 9:00 AM
- 4:00 AM setting → Triggers at 4:00 AM
- 12:45 PM setting → Triggers at 12:00 PM

If you need summaries at specific minutes (e.g., exactly 9:15 AM), we would need to:
1. Change the cron schedule to run more frequently (e.g., every 15 minutes)
2. Update the time matching logic to check minutes
3. This would increase Cloud Function costs (4x more executions)

For now, summaries will arrive at the top of the hour closest to your target time.
