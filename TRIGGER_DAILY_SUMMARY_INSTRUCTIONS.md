# Trigger Daily Summary Email - Instructions

Since the Cloud Functions have been successfully deployed with the corrected logic, you can trigger the daily summary email manually using the Firebase Console.

## Option 1: Firebase Console (Recommended)

1. Go to the Firebase Console: https://console.firebase.google.com/
2. Select your project (Plan with Hands)
3. Navigate to **Functions** in the left sidebar
4. Find the function named **triggerDailySummary**
5. Click on it, then click **"Testing"** tab
6. In the request body, enter:
   ```json
   {
     "data": {
       "orgId": "3qjYzHagWmfbnMieJ1aj",
       "targetDate": "2025-10-01"
     }
   }
   ```
7. Click **"Run Test"**

The email should be sent to con.lawless@gmail.com with the corrected logic showing:
- **Tasks Incomplete: 152** (instead of "Tasks Missed: 0")
- **⚠️ 152 tasks require attention** (instead of "All tasks completed successfully")

## Option 2: Using curl (requires auth token)

```bash
# First, get your Firebase auth token
firebase login:ci

# Then use the token in this command
curl -X POST \
  "https://us-central1-planwithhands.cloudfunctions.net/triggerDailySummary" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "orgId": "3qjYzHagWmfbnMieJ1aj",
      "targetDate": "2025-10-01"
    }
  }'
```

## What was Fixed

The deployment on [timestamp] included these critical fixes:

1. **Dart Service (`daily_summary_service.dart`)**:
   - Changed `if (!isCompleted && reason != null)` to `if (!isCompleted)`
   - Now ALL incomplete tasks are counted, not just those with reasons

2. **TypeScript Function (`scheduledDailySummary.ts`)**:
   - Fixed `processTaskForSummary` to use `hasReason` flag
   - Updated `generateNotableItemsForEmail` to calculate `incompleteTasks = totalTasks - completedTasks`
   - Fixed `buildEnhancedHtmlSections` to use `incompleteTasks` instead of `missedTaskEntries.length`
   - Changed metric name from "Tasks Missed" to "Tasks Incomplete" for clarity

3. **Email Logic**:
   - "All tasks completed successfully" only shows when `incompleteTasks === 0`
   - Now properly displays "⚠️ X tasks require attention" when incomplete tasks exist

## Verification

After triggering the email, verify that:
- Subject line still shows "7% Complete (11/163 tasks)"
- Body shows "Tasks Incomplete: 152" instead of "Tasks Missed: 0"
- Summary shows "⚠️ 152 tasks require attention" instead of "All tasks completed successfully"
- Email arrives at con.lawless@gmail.com
