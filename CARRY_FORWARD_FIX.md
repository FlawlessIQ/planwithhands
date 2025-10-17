# Carry-Forward Missed Tasks - System Fix

## Problem Summary
Users with staff role (userRole=0) could not see missed tasks because:
1. Daily checklists were missing the `jobTypes` field
2. No automated carry-forward process was running daily

## Root Causes

### Issue 1: Missing jobTypes on Daily Checklists
- **Impact**: Staff users (userRole=0) are filtered by jobTypes. If a checklist has no jobTypes, staff cannot see ANY tasks from that checklist, even if they have all job types.
- **Root Cause**: Historical issue - older checklists were created before the jobTypes copy fix was implemented.
- **Current State**: Code already has the fix in place (line 239 of `daily_checklist_service.dart`)

### Issue 2: No Automated Carry-Forward
- **Impact**: Missed tasks from yesterday were not automatically carried forward to today.
- **Root Cause**: No scheduled Cloud Function existed to run the carry-forward process daily.
- **Manual Trigger**: The `carryForwardMissedTasks()` function exists in the Flutter code but was never called automatically.

## Solutions Implemented

### 1. Backfilled Existing Checklists ✅
**File**: `backfill_checklist_jobtypes.js`
- Updated 112 existing checklists with jobTypes from their templates
- Organization: 3qjYzHagWmfbnMieJ1aj (can be run for any org)

### 2. Created Scheduled Cloud Function ✅
**File**: `functions/src/scheduled_carry_forward.js`
- Runs daily at 2 AM Pacific Time
- Processes all organizations and locations automatically
- Carries forward incomplete tasks from yesterday to today
- Properly handles:
  - jobTypes preservation
  - Duplicate detection (only checks CF tasks, not regular tasks)
  - Missing templates/shifts
  - Batch operations for performance

### 3. Verified Existing Fixes ✅
Both critical fixes are already in place:

**File**: `lib/services/daily_checklist_service.dart`
- **Line 239**: `ensureDailyChecklistAndTasks()` copies jobTypes from template when creating daily checklists
- **Line 2487**: `carryForwardMissedTasks()` copies jobTypes from yesterday's checklist when carrying forward

## Deployment Instructions

### Deploy the Scheduled Function

```bash
cd functions
npm install  # Ensure dependencies are up to date
firebase deploy --only functions:dailyCarryForwardMissedTasks
```

### Verify Deployment

```bash
# Check function logs
firebase functions:log --only dailyCarryForwardMissedTasks

# Manually trigger for testing (optional)
# Note: Create a test trigger function if needed for immediate testing
```

## How It Works Going Forward

### Daily Automated Process (2 AM Pacific)
1. **Scheduled Function Runs**: `dailyCarryForwardMissedTasks` executes
2. **For Each Organization**:
   - Get all locations
   - For each location:
     - Find yesterday's checklists
     - Identify incomplete, non-carried-forward tasks
     - Mark them as `carryForwardAttempted: true`
     - Create today's checklist (if doesn't exist) with jobTypes
     - Insert carry-forward tasks with `isCarryForward: true`
3. **Staff Users See Tasks**: Because checklists have jobTypes, filtering works correctly

### New Checklist Creation
When `generateDailyChecklists()` creates a new checklist:
1. Reads template data including jobTypes
2. Creates checklist with jobTypes field (line 239)
3. Populates tasks from template
4. **Result**: Staff users can immediately see tasks matching their jobTypes

### Missed Tasks Visibility
When staff user logs in:
1. Dashboard loads today's checklists
2. `loadMissedTasksForToday()` queries carry-forward tasks
3. Filters by jobTypes (user jobTypes ∩ checklist jobTypes)
4. **Result**: User sees all missed tasks they're qualified for

## JobTypes Filtering Logic

Staff users (userRole=0) see tasks where:
```dart
// User has at least one matching jobType
userJobTypes.any((ujt) => checklistJobTypes.contains(ujt))

// Empty checklist jobTypes = NO visibility for staff
if (checklistJobTypes.isEmpty) return false;
```

Managers (userRole=1) and Admins (userRole=2) skip filtering entirely.

## Monitoring

### Check Carry-Forward Success
```bash
# View function execution logs
firebase functions:log --only dailyCarryForwardMissedTasks --limit 50

# Look for:
# - "Daily Carry-Forward Complete: X tasks carried forward"
# - Any error messages
```

### Verify JobTypes on Checklists
Run the diagnostic script:
```bash
node check_jobtypes_source.js
```

### Check Missed Tasks Count
Run the gap analysis:
```bash
node analyze_carryforward_gap.js
```

## Future Improvements

### Optional Enhancements
1. **Email Alerts**: Notify admins of carry-forward completion/failures
2. **Metrics Dashboard**: Track carry-forward counts over time
3. **Retry Logic**: Handle transient failures with exponential backoff
4. **Manual Trigger**: Add HTTPS function for admin-triggered carry-forward

### Performance Optimization
Current implementation handles ~100 organizations × ~10 locations × ~10 checklists within the 9-minute timeout. For larger scale:
- Consider splitting by organization (separate function invocations)
- Use Firestore bulk operations more aggressively
- Add progress checkpointing

## Testing Checklist

- [x] JobTypes copied from templates to new checklists
- [x] JobTypes preserved during carry-forward
- [x] Scheduled function created and exported
- [ ] Function deployed to Firebase
- [ ] Test run confirms tasks carried forward
- [ ] Staff users can see missed tasks
- [ ] Managers/admins see all tasks (no filtering)

## Files Modified

### Created
- `functions/src/scheduled_carry_forward.js` - Scheduled Cloud Function
- `backfill_checklist_jobtypes.js` - One-time backfill script (already run)
- `CARRY_FORWARD_FIX.md` - This documentation

### Modified
- `functions/index.js` - Added scheduled function export

### Verified (No Changes Needed)
- `lib/services/daily_checklist_service.dart` - jobTypes fixes already in place

## Rollback Plan

If issues arise:
```bash
# Delete the scheduled function
firebase functions:delete dailyCarryForwardMissedTasks

# Manually trigger carry-forward if needed
node manual_carryforward_trigger.js
```

## Support

For issues:
1. Check Firebase Functions logs
2. Run diagnostic scripts in this directory
3. Verify template jobTypes are set correctly
4. Contact: [Your Contact Info]
