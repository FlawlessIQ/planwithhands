# Dashboard Task Display Issue - Investigation Summary

## Date: October 15, 2025

## Problem Statement
Tasks are not displaying on user dashboard - checklists show "0 of 0 tasks completed" even though tasks exist in the database.

## Symptoms
1. User sees "Missed Tasks: 17 tasks across 3 shifts" ✅ Working
2. Individual checklists show "0 of 0 tasks completed" ❌ Not working
3. Checklists are visible: "Bar closing" and "Dish Pit -Night"

## Investigation Findings

### What's Working ✅
1. **Checklists are being found:**
   - `[Dashboard] 🔥 Found 2 existing checklists for shift Closing`
   - Bar closing (Bartender)
   - Dish Pit -Night (Dishwasher)

2. **Missed tasks component works:**
   - `[MissedTasks][NX] Raw CF docs today=17`
   - `[DailyChecklistService] Streamed 2 tasks from subcollection` (Bar closing)
   - `[DailyChecklistService] Streamed 5 tasks from subcollection` (Dish Pit)
   - Tasks ARE in the database subcollections

3. **Shift visibility filtering works:**
   - Closing shift visible at 22:35 (within window)
   - Other shifts properly hidden

### What's NOT Working ❌
1. **Task hydration in dashboard is NOT running:**
   - Expected logs NOT appearing:
     * `[Dashboard] Checklist X already has Y inline tasks`
     * `[Dashboard] Hydrating X subcollection tasks for checklist Y`
     * `[Dashboard] No subcollection tasks found for checklist X`
   
2. **Return statement log is missing:**
   - Expected: `[Dashboard] Returning 2 checklists for shift Closing. Task counts: [...]`
   - NOT appearing in console logs

## Root Cause Hypothesis

The task hydration code at lines 1922-1960 in `user_dashboard_page.dart` is either:
1. **Not being executed** - The function returns early or takes a different path
2. **Being executed but tasks are wiped** - Tasks are hydrated but then cleared by subsequent code
3. **Silent failure** - An exception is being caught and swallowed

## Key Code Locations

### Task Hydration Code (Line 1922-1960)
```dart
// NEW: Hydrate tasks from subcollection if parent 'tasks' array is empty
for (int i = 0; i < checklists.length; i++) {
  final checklist = checklists[i];
  if (checklist.tasks.isNotEmpty) {
    continue; // already has inline tasks
  }
  try {
    final tasksSnap = await FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('locations')
        .doc(locId)
        .collection('daily_checklists')
        .doc(checklist.id)
        .collection('tasks')
        .orderBy('order')
        .get();
    // ... hydrate tasks
  } catch (e) {
    logger.w('[Dashboard] Failed hydrating tasks for checklist ${checklist.id}: $e');
  }
}
```

### Potential Problem Areas
1. **Auto-repair logic (Lines 2035-2134)**: Rebuilds checklists WITHOUT hydration
2. **Fallback generation (Lines 2137+)**: Generates new checklists WITHOUT hydration
3. **Early return (Line 2228)**: Returns generated checklists before main return

## Debug Changes Made
Added debug logging to identify where the issue occurs:
1. Log before hydration loop starts
2. Log for each checklist before hydration attempt
3. Log at return statement showing final task counts

## Next Steps
1. Wait for Flutter rebuild to complete
2. Navigate to dashboard in browser
3. Check console for new debug logs:
   - `🔥🔥🔥 STARTING TASK HYDRATION FOR X CHECKLISTS`
   - `🔥 HYDRATION CHECK: Checklist X has Y tasks initially`
   - `🔥🔥🔥 RETURNING X CHECKLISTS WITH TASK COUNTS: ...`
4. Determine exact code path being taken
5. Fix the issue based on findings

## Possible Solutions
Once we identify the exact issue:

### If hydration is not running:
- Check for early returns or exceptions
- Verify the checklists list is populated before hydration

### If auto-repair is wiping tasks:
- Ensure hydration happens AFTER auto-repair
- Or add hydration inside auto-repair logic

### If tasks are lost after hydration:
- Ensure no code clears/replaces checklists array after hydration
- Check for immutability issues with copyWith

## Related Files
- `lib/features/dashboard/pages/user_dashboard_page.dart` (Lines 1670-2240)
- `lib/services/daily_checklist_service.dart` (Missed tasks component)
- `functions/src/dailyGenerator.ts` (Creates tasks in subcollections)
- `functions/src/scheduledCarryForward.ts` (Carry-forward logic)
